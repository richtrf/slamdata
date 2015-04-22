module View.File.Modal where

import Control.Plus
import Control.Functor (($>))
import Data.Maybe (Maybe(..), maybe)
import Model.File
import EffectTypes
import View.File.Modal.Common
import View.File.Modal.ShareDialog
import View.File.Modal.RenameDialog
import Controller.File (handler)
import qualified Halogen.HTML as H
import qualified Halogen.HTML.Attributes as A
import qualified Halogen.HTML.Events as E
import qualified Halogen.HTML.Events.Handler as E
import qualified Halogen.HTML.Events.Monad as E
import qualified Halogen.Themes.Bootstrap3 as B

modal :: forall p e. State -> H.HTML p (E.Event (FileAppEff e) Input)
modal state =
  H.div [ A.classes ([B.modal, B.fade] <> maybe [] (const [B.in_]) state.dialog)
        , E.onClick (E.input_ $ SetDialog Nothing)
        ]
        [ H.div [ A.classes [B.modalDialog] ]
                [ H.div [ E.onClick (\_ -> E.stopPropagation $> empty)
                        , A.classes [B.modalContent]
                        ]
                        (modalContent state.dialog)
                ]
        ]

    where

    modalContent :: Maybe DialogResume -> [H.HTML p (_ Input)]
    modalContent Nothing = []
    modalContent (Just dialog) = dialogContent dialog

    dialogContent :: DialogResume -> [H.HTML p (_ Input)]
    dialogContent (ShareDialog url) = shareDialog url
    dialogContent (RenameDialog dialog) = renameDialog dialog
    dialogContent MountDialog = emptyDialog "Mount"
    dialogContent ConfigureDialog = emptyDialog "Configure"

    emptyDialog :: forall i. String -> [H.HTML p i]
    emptyDialog title = [ header $ h4 title
                        , body []
                        , footer []
                        ]
