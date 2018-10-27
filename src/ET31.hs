{-# LANGUAGE DataKinds
, ExtendedDefaultRules
, LambdaCase
, OverloadedStrings
, TupleSections #-}

module ET31 (
  et31
  , colorArrows
  ) where

import Control.Concurrent (forkIO, killThread)
import Control.Concurrent.MVar
import Control.Monad (forever)
import qualified Data.Map as M
import qualified Data.Set as S
import Vivid
import Vivid.OSC

import ET31.Keyboard
import Util.Byte
import Util.Network
import Synth
import Types.App
import Types.Button
import Window.Keyboard
import Window.Shift
import Window.Sustain


-- | PITFALL: Order matters.
-- Windows listed first are "on top of" later ones.
-- Key presses are handled by the first window containing them.
windows = [sustainWindow, shiftWindow, keyboardWindow]

et31 :: IO State
et31 = do
  inbox <- receivesAt "127.0.0.1" 11111
  toMonome <- sendsTo (unpack localhost) 13993
  voices <- let places = [(a,b) | a <- [0..15], b <- [0..15]]
    in M.fromList . zip places <$> mapM (synth boop) (replicate 256 ())
  let initialAnchor = 2 :: Int
  mst <- newMVar $ State { inbox = inbox
                         , toMonome = toMonome
                         , voices = voices
                         , anchor = initialAnchor
                         , shift = 0
                         , fingers = S.empty
                         , sustainOn = False
                         , sustained = S.empty
                         }

  colorArrows toMonome
  colorAnchors toMonome initialAnchor LedOn

  responder <- forkIO $ forever $ do
    decodeOSC <$> recv inbox 4096 >>= \case
      Left text -> putStrLn . show $ text
      Right osc -> let switch = readSwitchOSC osc
                   in  handleSwitch windows mst switch

  let loop :: IO State
      loop = getChar >>= \case
        'q' -> do close inbox
                  mapM_ free (M.elems voices)
                  killThread responder
                  st <- readMVar mst
                  colorAnchors toMonome (anchor st) LedOff
                  return st
        _   -> loop
  loop
