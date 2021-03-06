{-|

Test fixtures.

-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Reference (

  -- ** Timestamp
  testTimestamp,
  unsafeTimestamp,

  -- ** Address
  testAddr,
  testAddr2,
  testAddrValid,
  testShowAddr,

  -- ** Transaction Headers
  testTransfer,
  testCreateAccount,
  testCreateAsset,
  testCreateContract,
  testRevokeAccount,
  testCall,
  testBind,
  testSyncLocal,

  -- ** Transaction
  testTx,

  -- ** Block
  testGenesis,
  testBlock,
  testChain,
  testBlockHash,

  -- ** Asset
  testBalance,
  testAsset1,
  testAsset2,
  testAsset3,
  testAsset4,
  testAsset4Addr,
  testHoldings,

  -- ** Account
  testTimezone,
  testAccount,
  testAccount2,

  -- ** Contract
  testContract,

  -- ** Storage
  testStorage,
  testGlobalStorage,
  testLocalStorage,
  testHashStorage,

  -- ** Script
  defX,
  getX,
  setX,
  transX,
  testScript,
  testCode,


  -- ** DB
  defaultTxDb,
  testDb,

  -- ** Network.P2P.Message
  txMsg,
  syncMsg,
  poolMsg,
  pingMsg,
  pongMsg,
  blockMsg,
  getBlockAtIdxMsg,
  versionMsg,
  notFoundMsg,
  serviceRestartMsg,
  resetMemPoolMsg,

  -- ** Network.P2P.Consensus
  testSignBlockMsg,
  testBlockSigMsg,

  -- ** Key
  testSig,
  testSigDecode,
  testPub,
  testPriv,
  testPub2,
  testPriv2,
  testNonce,
  testKeyExport,

  testDH,
  testDHPoint,
  testDHSecret,
  testDHSecret',

  testEncrypt,
  testDecrypt,

  testRecover,

  -- ** Consensus
  testPoA,

  -- ** TxLog
  testTxLog,

) where

import Protolude

import Unsafe (unsafeFromJust)
import System.IO.Unsafe (unsafePerformIO)

import qualified Crypto.PubKey.ECC.Types as ECC
import qualified Crypto.PubKey.ECC.ECDSA as ECDSA
import qualified Crypto.PubKey.ECC.DH as DH
import qualified Crypto.Hash.MerkleTree as Merkle
import qualified Crypto.Number.Serialize as CNS

import qualified Data.ByteString as BS
import qualified Data.ByteArray as B
import qualified Data.ByteArray.Encoding as B
import qualified Data.Set as Set
import qualified Data.Serialize as S

import Account
import Address
import Asset
import Block
import Contract
import Hash
import Encoding
import Network.P2P.Message
import Network.P2P.Consensus as NPC
import DB
import Transaction
import Storage
import Script
import Script.Graph

import qualified SafeInteger as SI
import qualified SafeString as SS

import qualified Key
import qualified Time
import qualified Asset
import qualified Block
import qualified TxLog
import qualified Delta
import qualified Script
import qualified Address
import qualified Account
import qualified SafeString
import qualified Transaction
import qualified Data.Map as Map
import qualified Network.P2P.Consensus as NPC
import qualified Network.P2P.Message as NPM
import qualified Network.P2P.Service as Service
import qualified Script.Graph as Graph

import Consensus.Authority.Types as CAT

import System.FilePath

-------------------------------------------------------------------------------
-- Timestamp Fixtures
-------------------------------------------------------------------------------

testTimestamp :: Time.Timestamp
testTimestamp = 1231006505

{-# NOINLINE unsafeTimestamp #-}
unsafeTimestamp :: Time.Timestamp
unsafeTimestamp = unsafePerformIO Time.now

-------------------------------------------------------------------------------
-- Address Fixtures
-------------------------------------------------------------------------------

testAddr :: Address
testAddr = deriveAddress testPub

testAddr2 :: Address
testAddr2 = deriveAddress testPub2

testAddrValid :: IO ()
testAddrValid = do
  (pub, addr) <- newPair
  print $ validateAddress addr
  print $ verifyAddress pub addr

testShowAddr :: Text
testShowAddr = showAddr (undefined :: AContract, testAddr)

-------------------------------------------------------------------------------
-- Transaction Header Fixtures
-------------------------------------------------------------------------------

assetAddr_, toAddr_ :: Address.Address
assetAddr_ = Address.parseAddress "43WRxMNcnYgZFcE36iohqrXKQdajUdAxeSn9mzE1ZedB"
toAddr_ = Address.parseAddress "7mR5d7s6cKB4qjuX1kiwwNtygfURhFQ9TKvEd9kmq6QL"

testArgs :: [Value]
testArgs = [
    (VInt 1)
  , (VFloat 3.5)
  , (VBool True)
  , (VAddress testAddr)
  , (VContract testAddr)
  , (VMsg "Hello world")
  , VVoid
  , VUndefined
  ]

testTransfer :: TransactionHeader
testTransfer = TxAsset Transfer {
    assetAddr = Reference.assetAddr_
  , toAddr    = Reference.toAddr_
  , balance   = 1
  }

testCreateAccount :: TransactionHeader
testCreateAccount = TxAccount CreateAccount {
    pubKey   = Key.unHexPub (Key.hexPub testPub)
  , timezone = "GMT"
  , metadata = Map.fromList []
  }

testCreateAsset :: TransactionHeader
testCreateAsset = TxAsset CreateAsset {
    assetName = "test"
  , supply    = 1000
  , reference = Just Asset.Token
  , assetType = Asset.Discrete
  }

testCreateContract :: TransactionHeader
testCreateContract = TxContract CreateContract {
    address = testAddr
  , contract = SafeString.fromBytes' testCode
  }

testRevokeAccount :: TransactionHeader
testRevokeAccount = TxAccount RevokeAccount {
    address = testAddr
  }

testCall :: TransactionHeader
testCall = TxContract Call {
    address = testAddr
  , method  = "get"
  , args    = []
  }

testBind :: TransactionHeader
testBind = TxAsset Bind {
    assetAddr    = Reference.assetAddr_
  , contractAddr = Reference.toAddr_
  , bindProof    = Key.getSignatureRS testSig
  }

testSyncLocal :: TransactionHeader
testSyncLocal = TxContract $
  SyncLocal testAddr (InitialCommit (SI.toSafeInteger' 1, SI.toSafeInteger' 2))

-------------------------------------------------------------------------------
-- Transaction Fixtures
-------------------------------------------------------------------------------

testTx :: TransactionHeader -> Transaction
testTx hdr = tx
  where
    Just sig = Key.signSWith testPriv testNonce hdr
    tx = Transaction {
      header    = hdr
    , origin    = testAddr
    , to        = Nothing
    , signature = Key.encodeSig sig
    , timestamp = testTimestamp
    }

-------------------------------------------------------------------------------
-- Block Fixtures
-------------------------------------------------------------------------------

testGenesis :: IO Block
testGenesis = do
  let
    txs       = []
    ts        = testTimestamp
    origin    = testAddr
    prevBlock = ""
    priv      = testPriv
    index     = 0

    header = BlockHeader {
      origin     = origin
    , prevHash   = prevBlock
    , merkleRoot = Merkle.mtHash (Merkle.mkMerkleTree txs)
    , timestamp  = ts
    , consensus  = testPoA
    }

    sig = unsafeFromJust $ Key.signSWith priv testNonce header
    blockSig = BlockSignature sig (Address.deriveAddress $ Key.toPublic priv)

  return $ Block.Block {
    header       = header
  , index        = index
  , signatures   = Set.singleton blockSig
  , transactions = txs
  }

-- XXX: not deterministic
-- | Test block signed with test key
testBlock :: Block -> IO Block
testBlock lastBlock = do
  -- Test transactions
  newBlock
    testAddr
    (hashBlock lastBlock)
    []
    (Block.index lastBlock + 1)
    testPriv
    testPoA

-- | Construct a test chain signed wdith test key
testChain :: IO [Block]
testChain = do
  block0 <- genesisBlock "83cb2aef3" testTimestamp testPoA
  block1 <- testBlock block0
  block2 <- testBlock block1
  block3 <- testBlock block2
  return [block0, block1, block2, block3]

testBlockHash :: IO ByteString
testBlockHash = do
  genesisBlock <- genesisBlock "29c9abd5" testTimestamp testPoA
  return $ hashBlock genesisBlock

-------------------------------------------------------------------------------
-- Asset Fixtures
-------------------------------------------------------------------------------

testBalance :: Text
testBalance = displayType (Fractional 6) 42

testAsset1 :: Asset
testAsset1 = Asset
  { name = "hamburgers"
  , issuedOn = testTimestamp
  , issuer = testAddr
  , supply = 100000
  , holdings = mempty
  , assetType = Discrete
  , reference = Just Security
  }

testAsset2 :: Asset
testAsset2 = Asset
  { name = "usd"
  , issuer = testAddr
  , issuedOn = testTimestamp
  , supply = 100
  , holdings = mempty
  , assetType = Fractional 2
  , reference = Just USD
  }

testAsset3 :: Asset
testAsset3 = Asset
  { name = "rights"
  , issuer = testAddr
  , issuedOn = testTimestamp
  , supply = 50
  , holdings = mempty
  , assetType = Binary
  , reference = Just Token
  }

testAsset4 :: Asset
testAsset4 =
  let holdings = Map.fromList [(testAddr, 10000),
                               (testAddr2, 10000)]
  in testAsset2 {holdings = holdings, supply = 10000000}

testAsset4Addr :: Address
testAsset4Addr = Address.fromRaw "H5ixx7TRYT1paYYAkqMDAiLBvwqb1m6ZoTbZsGDBBfL7" -- generate with testPriv to generate sig on testAsset4

testHoldings :: IO (Either AssetError Asset)
testHoldings = do
  a1 <- Address.newAddr
  a2 <- Address.newAddr

  let x = testAsset1
  let transaction = pure testAsset1 >>=
        adjustHolding a1 1000 >>= adjustHolding a2 1000
  return transaction

-------------------------------------------------------------------------------
-- Account
-------------------------------------------------------------------------------

testTimezone :: ByteString
testTimezone = "GMT"

testAccount :: Account
testAccount = Account
  { publicKey   = testPub
  , address     = Address.deriveAddress testPub
  , nodeKey     = 0x1
  , timezone    = "America/New_York"
  , metadata    = Map.fromList [
        ("Company", "Adjoint Inc.")
      ]
  }

testAccount2 :: Account
testAccount2 = Account
  { publicKey   = testPub2
  , address     = Address.deriveAddress testPub2
  , nodeKey     = 0x1
  , timezone    = "America/Boston"
  , metadata    = Map.fromList [
        ("Company", "Adjoint Inc.")
      ]
  }

-------------------------------------------------------------------------------
-- Contract
-------------------------------------------------------------------------------

testContract :: Time.Timestamp -> Contract
testContract now = Contract {
    timestamp     = now
  , script        = testScript
  , globalStorage = testGlobalStorage
  , localStorage  = Map.singleton testAddr testLocalStorage
  , localStorageVars =  Set.empty
  , methods       = Script.methodNames testScript
  , state         = Graph.GraphInitial
  , address       = testAddr
  , owner         = testAddr
  }

------------------------------------------------------------------------------------
-- Storage
-------------------------------------------------------------------------------

testStorage :: Storage
testStorage = Map.fromList [
    ("a", VInt 3)
  , ("b", VFloat 3.14)
  , ("c", VBool True)
  , ("d", VAddress testAddr)
  , ("e", VVoid)
  , ("f", VCrypto $ SI.toSafeInteger' 42)
  ]

testGlobalStorage :: GlobalStorage
testGlobalStorage = GlobalStorage testStorage

testLocalStorage :: LocalStorage
testLocalStorage = LocalStorage crypto
  where
    crypto = Map.filter f testStorage
    f (VCrypto _) = True
    f _           = False

testHashStorage :: (Int, Schema)
testHashStorage = (hashStorage testStorage, Storage.storageSchema testStorage)

-------------------------------------------------------------------------------
-- Script
-------------------------------------------------------------------------------

testLocated :: a -> Located a
testLocated = Located NoLoc

defX :: Def
defX = GlobalDef TInt "x" (testLocated $ LInt 0)

setX :: Method
setX = Method (Main "set") "setX" [] $ eseq NoLoc $
  [ testLocated $ EAssign "x" (testLocated $ ELit $ testLocated (LInt 42))
  , testLocated $ ECall "transitionTo" [(testLocated $ ELit $ testLocated (LState "get"))]
  , testLocated $ ERet (testLocated $ ELit $ testLocated $ LVoid)
  ]

getX :: Method
getX = Method (Main "get") "getX" [] $ eseq NoLoc $ [
    testLocated $ ERet (testLocated $ EVar $ testLocated "x")
  ]

transX :: [Transition]
transX = [
    Arrow Initial (Step "set")
  , Arrow (Step "set") (Step "get")
  ]

testScript :: Script
testScript = Script [defX] transX [getX, setX]

testCode :: ByteString
testCode =
  "global float x = 0.0; \
  \ local int y = 7;\
  \ asset z = 'H1tbrEKWGpbPjSeG856kz2DjViCwMU3qTw3i1PqCLz65'; \
  \ contract c = 'H1tbrEKWGpbPjSeG856kz2DjViCwMU3qTw3i1PqCLz65'; \
  \ account a = 'H1tbrEKWGpbPjSeG856kz2DjViCwMU3qTw3i1PqCLz65'; \
  \ setX (int z) { \
  \   x = 42.0;\
  \   y = y * z;\
  \   return x;\
  \ }\
  \ getX () {\
  \   j = 10 + 7 * 10;\
  \   k = j;\
  \   l = k;\
  \   return l; \
  \ }\
  \ f (int j, bool k) { \
  \   if (k) { return j; } else { return -1; }; \
  \ }\
  \ g (asset f, account t) { \
  \   if (assetExists(f) && accountExists(t)) { \
  \     transferTo(f,20); \
  \     transferFrom(f, 20, t);\
  \   } else {\
  \     return void; \
  \   };\
  \ }"

-------------------------------------------------------------------------------
-- DB Fixtures
-------------------------------------------------------------------------------

-- | Cursor for transactions database
defaultTxDb :: IO DB
defaultTxDb = create (".uplink" </> "transactions")

testDb :: IO ()
testDb = do
  let root = ".uplink"
  rc <- setupExistingDB root
  case rc of

    Left err -> do
      putText "Testing existing database."
      testDB root
      return ()

    Right _  -> do
      blockDB <- BlockDB <$> DB.create (blockDir root)

      blocks <- testChain
      writeBlocks blockDB blocks

      res <- lookupBlock blockDB 0
      print res

      Right chain <- allBlocks blockDB
      print chain
      vchain <- Block.validateChain chain

      putText "Chain verified:"
      print vchain
      putText "Chain matches input:"
      print ((Block.sortBlocks blocks) == (Block.sortBlocks chain))

      close $ DB.unDB blockDB

-------------------------------------------------------------------------------
-- Network.P2P.Message Fixtures (Payloads) -- XXX Remove IO from all of these
-------------------------------------------------------------------------------

txMsg :: IO Message
txMsg = do
  let hdr = testCreateAccount
  let tx = testTx hdr
  let msg = NPM.SendTransactionMsg tx
  pure (NPM.SendTx msg)

poolMsg :: IO Message
poolMsg = do
  let hdr = testCreateAccount
  let tx0 = testTx hdr

  let msg = NPM.GetPoolMsg 30 (replicate 30 tx0)
  pure (NPM.MemPool msg)

syncMsg :: IO Message
syncMsg = do
  let msg = NPM.SyncHeadMsg (Hash.sha256 "") 0
  pure (NPM.SyncHead msg)

pingMsg :: IO Message
pingMsg = pure (NPM.Ping "")

pongMsg :: IO Message
pongMsg = pure (NPM.Pong "")

notFoundMsg :: IO Message
notFoundMsg = pure NPM.NotFound

versionMsg :: IO Message
versionMsg = pure (NPM.Version NPM.version)

getBlockAtIdxMsg :: IO Message
getBlockAtIdxMsg = do
  let msg = NPM.GetBlockMsg 1 "nid://127.0.1.1:8001:0"
  pure (NPM.GetBlock msg)

blockMsg :: IO Message
blockMsg = do
  blk <- testGenesis
  let msg = NPM.BlockMsg blk "XXX"
  pure (NPM.Block msg)

-- Test Messages

serviceRestartMsg :: NPM.TestMessage
serviceRestartMsg = NPM.ServiceRestart $
  NPM.ServiceRestartMsg Service.TestMessaging 42

resetMemPoolMsg :: NPM.TestMessage
resetMemPoolMsg = NPM.ResetMemPool NPM.ResetMemPoolMsg

-------------------------------------------------------------------------------
-- Network.P2P.Consensus Fixtures
-------------------------------------------------------------------------------

testSignBlockMsg :: IO NPC.SignBlockMsg
testSignBlockMsg = do
  (acc,(_,sk)) <- Account.newAccount "GMT" mempty
  let accAddr = Account.address acc
  pbHash <- testBlockHash
  let tx1 = testTx testCreateAccount
  let tx2 = testTx testCreateAccount
  block <- Block.newBlock accAddr pbHash [tx1,tx2] 1337 sk testPoA
  return $ NPC.SignBlockMsg block

testBlockSigMsg :: IO NPC.BlockSigMsg
testBlockSigMsg = do
  (acc,(_,sk)) <- Account.newAccount "GMT" mempty
  let accAddr = Account.address acc
  pbHash <- testBlockHash
  let tx1 = testTx testCreateAccount
  let tx2 = testTx testCreateAccount
  block <- Block.newBlock accAddr pbHash [tx1,tx2] 1337 sk testPoA
  blockSig' <- Key.sign sk (Block.hashBlock block)
  let blockSig = Block.BlockSignature blockSig' accAddr
  return $ NPC.BlockSigMsg blockSig

-------------------------------------------------------------------------------
-- Key
-------------------------------------------------------------------------------

testSigDecode :: IO Bool
testSigDecode = do
  (pk1, sk1) <- Key.new
  sig <- Key.sign sk1 "foo"
  let sigE = Key.encodeSig sig
  let Right sigD = Key.decodeSig sigE
  return $ sig == sigD

testDH :: IO (Key.PubKey, Key.PubKey, Bool)
testDH = do
  (priv1, pub1) <- Key.dhGenerateKeyPair -- client
  (priv2, pub2) <- Key.dhGenerateKeyPair -- server
  let Just s1 = Key.dhGetShared priv1 pub2
  let Just s2 = Key.dhGetShared priv2 pub1

  let sec1 = Key.secretToPrivate s1
  let sec2 = Key.secretToPrivate s2
  print (sec1, sec2)

  return (pub1, pub2, sec1 == sec2)

testRecover :: IO Bool
testRecover = do
  let k    = 101
  let Just sig = Key.signWith testPriv k testMsg
  let (rpub1, rpub2) = Key.recover sig testMsg
  return $ testPub == rpub1 || testPub == rpub2

testMsg :: ByteString
testMsg = "The quick brown fox jumped over the lazy dog."

testEncrypt  :: IO ByteString
testEncrypt = do
  let Just (DH.SharedKey key) = Key.dhGetShared testPriv testPub2
  print (B.unpack key)
  Key.encrypt key testMsg

testDecrypt :: IO (Maybe ByteString)
testDecrypt = do
  let Just (DH.SharedKey key) = Key.dhGetShared testPriv testPub2
  ciphertext <- Key.encrypt key testMsg
  print (B.unpack key)
  print ciphertext
  Key.decrypt key ciphertext

testDHPoint :: ECDSA.PublicPoint
testDHPoint = DH.calculatePublic Key.sec_p256k1 (ECDSA.private_d testPriv)

testDHSecret :: ByteString
testDHSecret = Encoding.base16 $ B.convert $ DH.getShared Key.sec_p256k1 (ECDSA.private_d testPriv) testDHPoint

testDHSecret' :: Integer
testDHSecret' = CNS.os2ip $ DH.getShared Key.sec_p256k1 (ECDSA.private_d testPriv) testDHPoint

testKeyExport :: IO ()
testKeyExport = do
  (pub, priv) <- Key.new
  let pem = Key.exportPriv (pub, priv)
  let Right (pub', priv') = Key.importPriv pem
  putStrLn pem
  print (pub==pub', priv==priv')

  let pem = Key.exportPub pub
  let Right pub'' = Key.importPub pem
  putStrLn pem
  print (pub==pub'')

-- Warning: If you change this, most of the tx serialization tests will fail;
-- The nonce is used to sign the transaction header, included in the tx body.
testNonce :: Integer
testNonce = 42

testSig :: ECDSA.Signature
testSig = ECDSA.Signature
  115136800820456833737994126771386015026287095034625623644186278108926690779567
  98245280522003505644797670843107276132602050133082625768706491602875725788467

-- | Test public key
testPub :: Key.PubKey
testPub = Key.PubKey
  ECDSA.PublicKey
    { public_curve = Key.sec_p256k1
    , public_q =
        ECC.Point
          79174541683660805620639640382768661759397823295690888507762753093299621916987
          71065057682299419085325030940046895916159750330092956837115984315857371796477
    }

-- | Test private key
testPriv :: ECDSA.PrivateKey
testPriv =
  ECDSA.PrivateKey
    { ECDSA.private_curve = Key.sec_p256k1
    , private_d =
        72637887363324669071595225655990695893413546682343152974463667925881860469868
    }

testPub2 :: Key.PubKey
testPub2 = Key.PubKey
  ECDSA.PublicKey
    { public_curve = Key.sec_p256k1,
      public_q =
        ECC.Point
          1214472788908201963423194854954899474972637934119143134374611198349064747631
          55018619338720117837520711191755301992479046934581364159114240410943276116468
    }

testPriv2 :: ECDSA.PrivateKey
testPriv2 =
  ECDSA.PrivateKey
    { ECDSA.private_curve = Key.sec_p256k1
    , private_d =
        63397430372085899480856522915791132982175202462259856053849906393820683762766
    }

-------------------------------------------------------------------------------
-- Consensus
-------------------------------------------------------------------------------

testPoA :: CAT.PoA
testPoA = CAT.PoA
  { validatorSet  = mempty
  , blockPeriod   = 1
  , blockGenLimit = 1
  , signerLimit   = 1
  , threshold     = 1
  , minTxs        = 1
  }

-------------------------------------------------------------------------------
-- TxLog
-------------------------------------------------------------------------------

testTxLog :: IO ()
testTxLog = do
  let dt1 = Delta.ModifyGlobal "a" (VFloat 3.14)
  let dt2 = Delta.ModifyGlobal "b" (VInt 3)
  TxLog.writeDeltas 0 (DB.txLogFile "node1") testAddr [dt1, dt2]
