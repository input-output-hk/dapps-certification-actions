{-# LANGUAGE PackageImports #-}
module Main where

import "plutus-contract-certification" Plutus.Contract.Test.Certification.Run
import "certification" Certification (certification)
import "base" System.IO
import "base" GHC.IO.Handle.FD

main :: IO ()
main = do
  res <- certifyWithOptions (defaultCertificationOptions { certOptOutput = False }) certification
  h <- fdToHandle 3
  hPutStrLn h $ certResJSON res
  hClose h
