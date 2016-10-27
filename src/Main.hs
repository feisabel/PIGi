module Main(main) where

import System.Environment
import Text.Parsec (parse)
import Lexical

printlextokens :: [PosToken] -> IO ()
printlextokens tokens = 
    mapM_ (print . snd) tokens

runlexparser :: String -> String -> IO ([PosToken])
runlexparser filename input =
    let result = parse lexparser filename input
    in case result of
         Left msg -> do print msg
                        fail "lexical error"

         Right tokens -> do printlextokens tokens
                            return tokens

run :: [String] -> IO ()
run ["-l", filename] = readFile filename >>= runlexparser filename >> return ()
run ["-l"] = getContents >>= runlexparser "(stdin)" >> return ()

main :: IO ()
main = do print "PIG language interpreter"
          getArgs >>= run 
