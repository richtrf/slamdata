module Controller.File.Item where

import Api.Fs (delete, children)
import Control.Monad.Aff (makeAff, attempt)
import Control.Monad.Aff.Class (liftAff)
import Control.Monad.Eff (Eff())
import Control.Monad.Eff.Class (liftEff)
import Control.Plus (empty)
import Controller.File.Common (open)
import Data.Array (filter)
import Data.DOM.Simple.Element (getElementById)
import Data.DOM.Simple.Encode (encodeURIComponent)
import Data.DOM.Simple.Window (document, globalWindow)
import Data.Either (Either(..))
import Data.Foldable (fold)
import Data.Inject1 (Inject1, inj)
import Data.Maybe (Maybe(..))
import Data.Path.Pathy
import Data.String (joinWith)
import DOM (DOM())
import Driver.File.Path (updatePath)
import EffectTypes (FileAppEff())
import Halogen.HTML.Events.Monad (Event(), async, andThen)
import Input.File (Input(), FileInput(SetDialog))
import Input.File.Item (ItemInput(..))
import Input.File.Rename (RenameInput(..))
import Model.File.Dialog (Dialog(..))
import Model.File.Dialog.Mount (initialMountDialog)
import Model.File.Dialog.Rename (initialRenameDialog)
import Model.File.Item (Item())
import Model.Resource
import Optic.Core ((.~))
import Routing.Hash (getHash, modifyHash)
import Utils (locationString)
import qualified Control.UI.ZClipboard as Z

toInput :: forall m a b. (Applicative m, Inject1 a b) => a -> m b
toInput = pure <<< inj

handleDeleteItem :: forall e. Item -> Event (FileAppEff e) Input
handleDeleteItem item = async $ do
  delete item.resource
  toInput $ ItemRemove item

handleMoveItem :: forall e. Item -> Event (FileAppEff e) Input
handleMoveItem item = do
  siblings <- liftAff $ children (parent item.resource)
  let dialog = RenameDialog $
               _{siblings = siblings} $
               initialRenameDialog item.resource 
  (toInput $ SetDialog (Just dialog))
    `andThen` \_ -> do
    getDirectories root

handleOpenItem :: forall e. Item -> Event (FileAppEff e) Input
handleOpenItem item = do
  liftEff $
    if isNotebook item.resource
    then open item false
    else if isFile item.resource
         then open item true
         else moveDown item
  empty

-- ATTENTION
-- This all should be moved to `initializer`
-- ATTENTION
handleShare :: forall e. Item -> Event (FileAppEff e) Input
handleShare item = async $ makeAff $ \_ k -> do
  url <- itemURL item
  k $ inj $ SetDialog (Just $ ShareDialog url)
  mbCopy <- document globalWindow >>= getElementById "copy-button"
  case mbCopy of
    Nothing -> pure unit
    Just btn -> void do
      Z.make btn >>= Z.onCopy (Z.setData "text/plain" url)

itemURL :: forall e. Item -> Eff (dom :: DOM | e) String
itemURL item = do
  loc <- locationString
  hash <- getHash
  pure if isFile item.resource
       then joinWith ""
            [ Config.notebookUrl
            , "#"
            , resourcePath item.resource
            , "/view"
            , "/?q=", encodeURIComponent ("select * from ...") ]
       else if isNotebook item.resource
            then joinWith "" [ Config.notebookUrl
                             , "#"
                             , resourcePath item.resource
                             , "/view"]
            else "#"



handleConfigure :: forall e. Item -> Event (FileAppEff e) Input
handleConfigure _ = toInput $ SetDialog (Just $ MountDialog initialMountDialog { new = false })

-- open dir or db
moveDown :: forall e. Item -> Eff (dom :: DOM | e) Unit
moveDown item = modifyHash $ updatePath (getPath $ item.resource)

getDirectories :: forall e. Resource -> Event (FileAppEff e) Input
getDirectories r = do
  ei <- liftAff $ attempt $ children r
  case ei of
    Right items -> do
      let cs = filter (\x -> isDirectory x || isDatabase x) items
      (toInput $ AddDirs cs) `andThen` \_ ->
        fold (getDirectories <$> cs)
    _ -> empty
