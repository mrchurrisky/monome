module Util.Byte (
  ByteString
  , pack
  , unpack
  , fi
  , numBetween
  , addPair
  , negPair
  )

where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 (pack, unpack)

-- | Because OSC needs a lot of Int32 values while I prefer Int.
fi :: (Integral a, Num b) => a -> b
fi = fromIntegral

numBetween :: Real a => a -> a -> a -> Bool
numBetween low high x = x >= low && x <= high

addPair :: (Int,Int) -> (Int,Int) -> (Int,Int)
addPair (a,b) (c,d) = (a+c, b+d)

negPair :: (Int,Int) -> (Int,Int)
negPair (a,b) = (-a,-b)
