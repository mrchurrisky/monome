{-# LANGUAGE TupleSections #-}

module Window.Shift (
  shiftWindow
  , colorAnchors
  , colorArrows
  ) where

import Control.Concurrent.MVar

import ET31.Keyboard
import Types.App
import Types.Button
import Util.Byte
import Util.Network


shiftWindow = Window {
  windowLabel = "shiftWindow"
  , windowContains = \(x,y) -> numBetween x 0 1 && numBetween y 13 15
  , windowHandler = handler
}

colorArrows :: Socket -> IO ()
colorArrows toMonome = mapM_ f [ (0,15),(0,14),(0,13)
                               , (1,14) ]
  where f = send toMonome . ledOsc "/monome" . (,LedOn) 

colorAnchors :: LedRelay -> Int -> Led -> IO ()
colorAnchors toMonome anchor led = mapM_ f xys
  where xys = enharmonicToXYs $ et31ToLowXY anchor
        f = toMonome . (,led)

handler :: MVar State -> LedRelay -> ((X,Y), Switch) -> IO ()
handler _   _        (_, SwitchOff) = return ()
handler mst toMonome (xy,SwitchOn ) = do
  st <- takeMVar mst
  let anchorShift = case xy of (0,15) -> 6
                               (0,14) -> 1
                               (1,14) -> -1
                               (0,13) -> -6
                               _ -> 0
      pitchShift = case xy of (0,15) -> -6
                              (1,15) -> 31
                              (0,14) -> -1
                              (1,14) -> 1
                              (0,13) -> 6
                              (1,13) -> -31
      newAnchor = anchor st + anchorShift
  colorAnchors toMonome (anchor st) LedOff
  colorAnchors toMonome newAnchor LedOn
  putMVar mst $ st { shift = shift st + pitchShift
                   , anchor = mod newAnchor 31 }
