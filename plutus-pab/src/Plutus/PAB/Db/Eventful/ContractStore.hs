{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs            #-}
{-# LANGUAGE LambdaCase       #-}
{-# LANGUAGE RankNTypes       #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators    #-}
module Plutus.PAB.Db.Eventful.ContractStore(
    handleContractStore
    ) where

import           Control.Monad                  (void)
import           Control.Monad.Freer            (Eff, Member, type (~>))
import           Control.Monad.Freer.Error      (Error, throwError)
import           Data.Aeson                     (Value)
import qualified Data.Map                       as Map
import           Plutus.Contract.State          (ContractResponse)
import qualified Plutus.PAB.Db.Eventful.Command as Command
import qualified Plutus.PAB.Db.Eventful.Query   as Query
import           Plutus.PAB.Effects.Contract    (ContractStore (..), PABContract (..))
import           Plutus.PAB.Effects.EventLog    (EventLogEffect, runCommand, runGlobalQuery)
import           Plutus.PAB.Events              (PABEvent)
import           Plutus.PAB.Events.Contract     (ContractPABRequest)
import           Plutus.PAB.Types               (PABError (..), Source (..))

-- | Handle the 'ContractStore' effect by storing states
--   in the eventful database.
handleContractStore ::
    forall t effs.
    ( Member (EventLogEffect (PABEvent (ContractDef t))) effs
    , Member (Error PABError) effs
    , State t ~ ContractResponse Value Value Value ContractPABRequest
    )
    => ContractStore t
    ~> Eff effs
handleContractStore = \case
    PutState def i state ->
        void
            $ runCommand @() @(PABEvent (ContractDef t))
                Command.updateContractInstanceState
                (InstanceEventSource i)
                (def, i, state)
    GetState i -> do
        contractState <- runGlobalQuery (Query.contractState @(ContractDef t))
        case Map.lookup i contractState of
            Nothing -> throwError $ ContractInstanceNotFound i
            Just k  -> pure k
    GetActiveContracts ->
        runGlobalQuery (Query.contractDefinition @(ContractDef t))
    PutStartInstance def i ->
        void $ runCommand @() @(PABEvent (ContractDef t))
            Command.startContractInstance
            PABEventSource
            (def, i)
    PutStopInstance i ->
        void $ runCommand @() @(PABEvent (ContractDef t))
            Command.stopContractInstance
            PABEventSource
            i
