{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}

-- | Transactions in the context of a consensus mode, and other types used in
-- the transaction submission protocol.
--
module Cardano.Api.InMode (

    -- * Transaction in a consensus mode
    TxInMode(..),
    fromConsensusGenTx,
    toConsensusGenTx,

    -- * Transaction id in a consensus mode
    TxIdInMode(..),
    toConsensusTxId,

    -- * Transaction validation errors
    TxValidationError(..),
    TxValidationErrorInCardanoMode(..),
    fromConsensusApplyTxErr,
  ) where

import           Cardano.Api.Eon.ByronEraOnly
import           Cardano.Api.Eon.ShelleyBasedEra
import           Cardano.Api.Eras
import           Cardano.Api.Modes
import           Cardano.Api.Tx
import           Cardano.Api.TxBody

import qualified Ouroboros.Consensus.Byron.Ledger as Consensus
import qualified Ouroboros.Consensus.Cardano.Block as Consensus
import qualified Ouroboros.Consensus.HardFork.Combinator as Consensus
import           Ouroboros.Consensus.HardFork.Combinator.AcrossEras (EraMismatch)
import qualified Ouroboros.Consensus.Ledger.SupportsMempool as Consensus
import qualified Ouroboros.Consensus.Shelley.HFEras as Consensus
import qualified Ouroboros.Consensus.Shelley.Ledger as Consensus
import qualified Ouroboros.Consensus.TypeFamilyWrappers as Consensus

import           Data.SOP.Strict (NS (S, Z))


-- ----------------------------------------------------------------------------
-- Transactions in the context of a consensus mode
--

-- | A 'Tx' in one of the eras supported by a given protocol mode.
--
-- For multi-era modes such as the 'CardanoMode' this type is a sum of the
-- different transaction types for all the eras. It is used in the
-- LocalTxSubmission protocol.
--
data TxInMode where
  -- | Everything we consider a normal transaction.
  --
  TxInMode
    :: Tx era
    -> EraInMode era CardanoMode
    -> TxInMode

  -- | Byron has various things we can post to the chain which are not
  -- actually transactions. This covers: update proposals, votes and
  -- delegation certs.
  --
  TxInByronSpecial
    :: Consensus.GenTx Consensus.ByronBlock
    -> EraInMode ByronEra CardanoMode
    -> TxInMode

deriving instance Show TxInMode

fromConsensusGenTx :: ()
  => ConsensusBlockForMode CardanoMode ~ block
  => ConsensusMode CardanoMode
  -> Consensus.GenTx block
  -> TxInMode
fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (Z tx'))) =
  TxInByronSpecial tx' ByronEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (Z tx')))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraShelley shelleyEraTx) ShelleyEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (Z tx'))))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraAllegra shelleyEraTx) AllegraEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (Z tx')))))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraMary shelleyEraTx) MaryEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (Z tx'))))))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraAlonzo shelleyEraTx) AlonzoEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (S (Z tx')))))))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraBabbage shelleyEraTx) BabbageEraInCardanoMode

fromConsensusGenTx CardanoMode (Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (S (S (Z tx'))))))))) =
  let Consensus.ShelleyTx _txid shelleyEraTx = tx'
  in TxInMode (ShelleyTx ShelleyBasedEraConway shelleyEraTx) ConwayEraInCardanoMode

toConsensusGenTx :: ()
  => ConsensusBlockForMode CardanoMode ~ block
  => TxInMode
  -> Consensus.GenTx block
toConsensusGenTx (TxInMode (ByronTx ByronEraOnlyByron tx) ByronEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (Z tx'))
  where
    tx' = Consensus.ByronTx (Consensus.byronIdTx tx) tx
    --TODO: add the above as mkByronTx to the consensus code,
    -- matching mkShelleyTx below

toConsensusGenTx (TxInByronSpecial gtx ByronEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (Z gtx))

toConsensusGenTx (TxInMode (ShelleyTx _ tx) ShelleyEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (Z tx')))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ tx) AllegraEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (Z tx'))))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ tx) MaryEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (Z tx')))))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ tx) AlonzoEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (Z tx'))))))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ tx) BabbageEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (S (Z tx')))))))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ tx) ConwayEraInCardanoMode) =
    Consensus.HardForkGenTx (Consensus.OneEraGenTx (S (S (S (S (S (S (Z tx'))))))))
  where
    tx' = Consensus.mkShelleyTx tx

toConsensusGenTx (TxInMode (ShelleyTx _ _) ByronEraInCardanoMode) =
  error "Cardano.Api.InMode.toConsensusGenTx: ShelleyTx In Byron era"

-- ----------------------------------------------------------------------------
-- Transaction ids in the context of a consensus mode
--

-- | A 'TxId' in one of the eras supported by a given protocol mode.
--
-- For multi-era modes such as the 'CardanoMode' this type is a sum of the
-- different transaction types for all the eras. It is used in the
-- LocalTxMonitoring protocol.
--
-- TODO Rename to TxIdInEra
data TxIdInMode where
  TxIdInMode
    :: CardanoEra era
    -> TxId
    -> TxIdInMode

toConsensusTxId :: ()
  => ConsensusBlockForMode CardanoMode ~ block
  => TxIdInMode
  -> Consensus.TxId  (Consensus.GenTx block)
toConsensusTxId (TxIdInMode ByronEra txid) =
  Consensus.HardForkGenTxId . Consensus.OneEraGenTxId . Z $ Consensus.WrapGenTxId txid'
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.ByronBlock)
  txid' = Consensus.ByronTxId $ toByronTxId txid

toConsensusTxId (TxIdInMode ShelleyEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (Z (Consensus.WrapGenTxId txid'))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardShelleyBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

toConsensusTxId (TxIdInMode AllegraEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (S (Z (Consensus.WrapGenTxId txid')))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardAllegraBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

toConsensusTxId (TxIdInMode MaryEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (S (S (Z (Consensus.WrapGenTxId txid'))))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardMaryBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

toConsensusTxId (TxIdInMode AlonzoEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (S (S (S (Z (Consensus.WrapGenTxId txid')))))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardAlonzoBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

toConsensusTxId (TxIdInMode BabbageEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (S (S (S (S (Z (Consensus.WrapGenTxId txid'))))))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardBabbageBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

toConsensusTxId (TxIdInMode ConwayEra txid) =
  Consensus.HardForkGenTxId (Consensus.OneEraGenTxId (S (S (S (S (S (S (Z (Consensus.WrapGenTxId txid')))))))))
 where
  txid' :: Consensus.TxId (Consensus.GenTx Consensus.StandardConwayBlock)
  txid' = Consensus.ShelleyTxId $ toShelleyTxId txid

-- ----------------------------------------------------------------------------
-- Transaction validation errors in the context of eras and consensus modes
--

-- | The transaction validations errors that can occur from trying to submit a
-- transaction to a local node. The errors are specific to an era.
--
data TxValidationError era where

     ByronTxValidationError
       :: Consensus.ApplyTxErr Consensus.ByronBlock
       -> TxValidationError ByronEra

     ShelleyTxValidationError
       :: ShelleyBasedEra era
       -> Consensus.ApplyTxErr (Consensus.ShelleyBlock (ConsensusProtocol era) (ShelleyLedgerEra era))
       -> TxValidationError era

-- The GADT in the ShelleyTxValidationError case requires a custom instance
instance Show (TxValidationError era) where
    showsPrec p (ByronTxValidationError err) =
      showParen (p >= 11)
        ( showString "ByronTxValidationError "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraShelley err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraShelley "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraAllegra err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraAllegra "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraMary err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraMary "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraAlonzo err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraAlonzo "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraBabbage err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraBabbage "
        . showsPrec 11 err
        )

    showsPrec p (ShelleyTxValidationError ShelleyBasedEraConway err) =
      showParen (p >= 11)
        ( showString "ShelleyTxValidationError ShelleyBasedEraConway "
        . showsPrec 11 err
        )

-- | A 'TxValidationError' in one of the eras supported by a given protocol
-- mode.
--
-- This is used in the LocalStateQuery protocol.
--
data TxValidationErrorInCardanoMode where
  TxValidationErrorInCardanoMode :: ()
    => TxValidationError era
    -> EraInMode era CardanoMode
    -> TxValidationErrorInCardanoMode

  TxValidationEraMismatch :: ()
    => EraMismatch
    -> TxValidationErrorInCardanoMode

deriving instance Show TxValidationErrorInCardanoMode


fromConsensusApplyTxErr :: ()
  => ConsensusBlockForMode CardanoMode ~ block
  => ConsensusMode CardanoMode
  -> Consensus.ApplyTxErr block
  -> TxValidationErrorInCardanoMode
fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrByron err) =
    TxValidationErrorInCardanoMode
      (ByronTxValidationError err)
      ByronEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrShelley err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraShelley err)
      ShelleyEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrAllegra err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraAllegra err)
      AllegraEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrMary err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraMary err)
      MaryEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrAlonzo err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraAlonzo err)
      AlonzoEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrBabbage err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraBabbage err)
      BabbageEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrConway err) =
    TxValidationErrorInCardanoMode
      (ShelleyTxValidationError ShelleyBasedEraConway err)
      ConwayEraInCardanoMode

fromConsensusApplyTxErr CardanoMode (Consensus.ApplyTxErrWrongEra err) =
    TxValidationEraMismatch err
