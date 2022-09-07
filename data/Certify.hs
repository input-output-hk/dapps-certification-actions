{-# LANGUAGE PackageImports #-}
module Main where

import "plutus-contract-certification" Plutus.Contract.Test.Certification.Run
import "certification" Certification (certification)
import "base" System.IO

main :: IO ()
main = do
  res <- certifyWithOptions (defaultCertificationOptions { certOptOutput = False }) certification
  hPutStrLn stdout $ certResJSON res
