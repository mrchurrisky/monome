module Types.App where

import qualified Data.Map as M
import qualified Data.Set as S

import Control.Concurrent.MVar
import Vivid

import Synth
import ET31.Keyboard
import Types.Button
import Util.Network


-- | `LedRelay` is for preventing one Window from writing to
-- the `Led`s of another `Window`.
type LedRelay = ((X,Y), Led) -> IO ()
type LedFilter = ((X,Y), Led) -> Bool

belongsHere :: [Window] -> Window -> LedFilter
belongsHere ws w = f where
  obscurers = takeWhile (/= w) ws -- the windows above `w`
  obscured :: (X,Y) -> Bool
  obscured xy = or $ map ($ xy) $ map windowContains obscurers
  f :: ((X,Y), Led) -> Bool
  f (xy,_) = not (obscured xy) && windowContains w xy

colorIfHere :: Socket -> [Window] -> Window -> LedRelay
colorIfHere toMonome ws w = f where
  f :: ((X,Y),Led) -> IO ()
  f msg = if belongsHere ws w msg
    then (send toMonome $ ledOsc "/monome" msg) >> return ()
    else return ()

data State = State {
    inbox :: Socket
  , toMonome :: Socket -- ^ PITFALL : some function arguments share this name
  , voices :: M.Map (X,Y) (Synth BoopParams)
  , anchor :: Int
  , shift :: Float -- ^ multiplicative; 2 = one octave higher
  , fingers :: S.Set (X,Y)
  , sustainOn :: Bool
  , sustained :: S.Set (X,Y)
  } deriving (Show, Eq)

data Window = Window {
    windowLabel :: String
  , windowContains :: (X,Y) -> Bool
  , windowInit :: MVar State -> LedRelay -> IO ()
  , windowHandler :: MVar State
    -> LedRelay -- ^ control Leds via this, not raw `send` commands
    -> [Window] -- ^ to construct an LedRelay to another Window, if needed
      -- PIFALL: Should be a list of all Windows -- not just, say, later ones.
    -> ((X,Y), Switch) -- ^ the incoming button press|release
    -> IO ()
  }

instance Eq Window where
  (==) a b = windowLabel a == windowLabel b

runWindowInit :: MVar State -> [Window] -> IO ()
runWindowInit mst allWindows = do
  st <- readMVar mst
  let toWindow w = colorIfHere (toMonome st) allWindows w
  mapM_ (\w -> windowInit w mst $ toWindow w) allWindows

handleSwitch :: [Window] -> MVar State -> ((X,Y), Switch) -> IO ()
handleSwitch               allWindows mst (xy,sw) =
  handleSwitch' allWindows allWindows mst (xy,sw) where
  -- `handleSwitch'` keeps the complete list of windows in its first arg,
  -- while iteratively discarding the head of its second.
  handleSwitch' allWindows []         _   _           = return ()
  handleSwitch' allWindows (w:ws)     mst sw @ (xy,_) = do
    st <- readMVar mst
    case windowContains w xy of
      True -> let ledRelay = colorIfHere (toMonome st) allWindows w
              in windowHandler w mst ledRelay allWindows sw
      False -> handleSwitch' allWindows ws mst sw
