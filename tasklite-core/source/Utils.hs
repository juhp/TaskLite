{-|
Several utility functions (e.g for parsing & serializing UTC stamps)
-}

module Utils where

import Protolude as P

import Codec.Crockford as Crock
import Data.Text as T
import Data.Text.Prettyprint.Doc hiding ((<>))
import Data.Hourglass
import Data.ULID
import Data.ULID.TimeStamp
import Data.ULID.Random


type IdText = Text
type TagText = Text

data Filter a = NoFilter | Only a
  deriving (Eq, Ord, Show)


(<++>) :: Doc ann -> Doc ann -> Doc ann
x <++> y =
  x <> softline <> softline <> y


(<$$>) :: Functor f => f a -> (a -> b) -> f b
(<$$>) =
  flip (<$>)


parseUtcNum :: Int -> Maybe DateTime
parseUtcNum number =
  parseUtc (show number)


parseUtc :: Text -> Maybe DateTime
parseUtc utcText =
  let
    utcString = unpack $ T.toLower utcText

    -- TOOD: Remove after https://github.com/vincenthz/hs-hourglass/issues/50
    addSpaceAfter10 = T.intercalate " " . T.chunksOf 10
    addSpaceAfter13 = T.intercalate " " . T.chunksOf 13
    unixMicro = "EPOCH ms us" :: [Char]
    unixMilli = "EPOCH ms" :: [Char]

    tParse :: [Char] -> Maybe DateTime
    tParse formatString =
      timeParse (toFormat formatString) utcString
  in
    -- From long (specific) to short (unspecific)
        (timeParse ISO8601_DateAndTime utcString)
    <|> (tParse "YYYY-MM-DDtH:MI")
    <|> (tParse "YYYYMMDDtHMIS")
    <|> (tParse "YYYY-MM-DD H:MI:S")
    <|> (tParse "YYYY-MM-DD H:MI")
    <|> (tParse "YYYY-MM-DD")
    <|> timeParse
          (toFormat unixMicro)
          (unpack $ (addSpaceAfter10 . addSpaceAfter13) utcText)
    <|> timeParse (toFormat unixMilli) (unpack $ addSpaceAfter10 utcText)
    <|> (tParse "EPOCH")


parseUlidUtcSection :: Text -> Maybe DateTime
parseUlidUtcSection encodedUtc = do
  let
    decodedUtcMaybe = (Crock.decode . unpack) encodedUtc
    getElapsed val = Elapsed $ Seconds $ val `div` 1000

  elapsed <- fmap getElapsed decodedUtcMaybe
  milliSecPart <- fmap (`mod` 1000) decodedUtcMaybe

  let nanoSeconds = NanoSeconds $ milliSecPart * 1000000

  pure $ timeGetDateTimeOfDay $ ElapsedP elapsed nanoSeconds


ulidTextToDateTime :: Text -> Maybe DateTime
ulidTextToDateTime =
    parseUlidUtcSection . T.take 10


parseUlidText :: Text -> Maybe ULID
parseUlidText ulidText = do
  let
    mkUlidTimeMaybe text = fmap toUlidTime (ulidTextToDateTime text)

    mkUlidRandomMaybe :: Text -> Maybe ULIDRandom
    mkUlidRandomMaybe = readMaybe . T.unpack . T.drop 10

  ulidTime   <- mkUlidTimeMaybe ulidText
  ulidRandom <- mkUlidRandomMaybe ulidText
  pure $ ULID ulidTime ulidRandom


-- TODO: Remove after https://github.com/vincenthz/hs-hourglass/issues/45
elapsedPToRational :: ElapsedP -> Rational
elapsedPToRational (ElapsedP (Elapsed (Seconds s)) (NanoSeconds ns)) =
  ((1e9 * (fromIntegral s)) + (fromIntegral ns)) / 1e9


toUlidTime :: DateTime -> ULIDTimeStamp
toUlidTime =
  mkULIDTimeStamp . realToFrac . elapsedPToRational . timeGetElapsedP


setDateTime :: ULID -> DateTime -> ULID
setDateTime ulid dateTime =
  ULID
    (toUlidTime dateTime)
    (random ulid)
