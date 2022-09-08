{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PackageImports      #-}
{-# LANGUAGE RecordWildCards     #-}
module Main where

import "certification" Certification (certification)
import "async" Control.Concurrent.Async
import "base" Control.Concurrent.Chan
import "base" Control.Concurrent.MVar
import "base" Control.Exception
import "aeson" Data.Aeson
import "aeson" Data.Aeson.Encoding
import "bytestring" Data.ByteString.Lazy.Char8 qualified as BSL8
import "text" Data.Text
import "base" GHC.IO.Handle.FD
import "plutus-contract-certification" Plutus.Contract.Test.Certification.Run
import "base" System.IO

renderTask :: CertificationTask -> Text
renderTask UnitTestsTask = "unit-tests"
renderTask StandardPropertyTask = "standard-property"
renderTask DoubleSatisfactionTask = "double-satisfaction"
renderTask NoLockedFundsTask = "no-locked-funds"
renderTask NoLockedFundsLightTask = "no-locked-funds-light"
renderTask CrashToleranceTask = "crash-tolerance"
renderTask WhitelistTask = "white-list"
renderTask DLTestsTask = "dl-tests"
renderTask _ = "unknown"

newtype CertificationTaskJSON = CertificationTaskJSON CertificationTask

instance ToJSON CertificationTaskJSON where
  toJSON (CertificationTaskJSON ct) = object
    [ "name" .= renderTask ct
    , "index" .= fromEnum ct
    ]
  toEncoding (CertificationTaskJSON ct) = pairs
    ( "name" .= renderTask ct
   <> "index" .= fromEnum ct
    )

data QCProgress = QCProgress
  { qcSuccesses :: !Integer
  , qcFailures :: !Integer
  , qcDiscarded :: !Integer
  }

instance ToJSON QCProgress where
  toJSON QCProgress {..} = object
    [ "successes" .= qcSuccesses
    , "failures" .= qcFailures
    , "discarded" .= qcDiscarded
    ]
  toEncoding QCProgress {..} = pairs
    ( "successes" .= qcSuccesses
   <> "failures" .= qcFailures
   <> "discarded" .= qcDiscarded
    )

data TaskResult = TaskResult
  { qcStatus :: !QCProgress
  , succeeded :: !Bool
  }

data CertificationTaskResult = CertificationTaskResult !(Maybe CertificationTask) !TaskResult

instance ToJSON CertificationTaskResult where
  toJSON (CertificationTaskResult ct (TaskResult {..})) = object
    [ "task" .= (CertificationTaskJSON <$> ct)
    , "qc-result" .= qcStatus
    , "succeeded" .= succeeded
    ]
  toEncoding (CertificationTaskResult ct (TaskResult {..})) = pairs
    ( "task" .= (CertificationTaskJSON  <$> ct)
   <> "qc-result" .= qcStatus
   <> "succeeded" .= succeeded
    )

data Progress = Progress
  { currentTask :: !(Maybe CertificationTask)
  , currentQc :: !QCProgress
  , finishedTasks :: ![CertificationTaskResult]
  }

instance ToJSON Progress where
  toJSON Progress {..} = object
    [ "current-task" .= (CertificationTaskJSON <$> currentTask)
    , "qc-progress" .= currentQc
    , "finished-tasks" .= finishedTasks
    ]
  toEncoding Progress {..} = pairs
    ( "current-task" .= (CertificationTaskJSON <$> currentTask)
   <> "qc-progress" .= currentQc
   <> "finished-tasks" .= finishedTasks
    )

postProgress :: Chan CertificationEvent -> Handle -> IO ()
postProgress eventChan h = handle (\BlockedIndefinitelyOnMVar -> pure ()) $
    go (0 :: Integer) initState
  where
    newQc = QCProgress 0 0 0

    initState = Progress
      { currentTask = Nothing
      , currentQc = newQc
      , finishedTasks = mempty
      }

    updateState (QuickCheckTestEvent Nothing) st = st
      { currentQc = (currentQc st) { qcDiscarded = qcDiscarded (currentQc st) + 1 }
      }
    updateState (QuickCheckTestEvent (Just True)) st = st
      { currentQc = (currentQc st) { qcSuccesses = qcSuccesses (currentQc st) + 1 }
      }
    updateState (QuickCheckTestEvent (Just False)) st = st
      { currentQc = (currentQc st) { qcFailures = qcFailures (currentQc st) + 1 }
      }
    updateState (StartCertificationTask ct) st = st
      { currentTask = Just ct
      , currentQc = newQc
      }
    updateState (FinishedTask res) st = st
      { currentTask = Nothing
      , currentQc = newQc
      , finishedTasks = (CertificationTaskResult (currentTask st) (TaskResult (currentQc st) res)) : (finishedTasks st)
      }

    go count st = do
      ev <- readChan eventChan
      let st' = updateState ev st
      BSL8.hPutStrLn h . encodingToLazyByteString $ pairs
        ( "status" .= st'
       <> "status-count" .= count
        )
      go (count + 1) st'

main :: IO ()
main = do
  eventChan <- newChan

  h <- fdToHandle 3

  let certOpts = defaultCertificationOptions
        { certOptOutput = False
        , certEventChannel = Just eventChan
        }
  (res, _) <- concurrently (certifyWithOptions certOpts certification) (postProgress eventChan h)

  BSL8.hPutStrLn h . encodingToLazyByteString $ pairs ( "success" .= res )
  hClose h
