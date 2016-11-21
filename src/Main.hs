module Main(main) where

import System.Environment
import Text.Parsec (parse)
import PosParsec
import Lexical
import Syntactic
import Exec.Prim (newProgramState, execIO)
import Exec.Interpreter
import StaticAnalyzer

runinterpreter :: SynModule -> IO ()
runinterpreter mod =
    do execIO (runmodule mod) newProgramState
       return ()


runsynparser :: [PosLexToken] -> String -> IO (Located SynModule)
runsynparser tokens filename =
    do let result = parse synmodule filename tokens
       case result of
            Left msg -> do print msg
                           fail "syntactic error"
            Right syntree -> return syntree

-- TODO: receive a list of SynModules, apply semModule to
-- each one.
runstaticanalyzer :: SynModule -> Either String SynModule
runstaticanalyzer mod = checkMod mod

printStaticAnalyzer :: Either String SynModule -> IO ()
printStaticAnalyzer x = case x of
                          Right x -> putStrLn "Ok"
                          Left msg -> putStrLn $ "Error : " ++ msg


printsyn :: SynModule -> IO ()
printsyn = print

printlex :: [PosLexToken] -> IO ()
printlex tokens = 
    mapM_ (print . ignorepos) tokens


runlexparser :: String -> String -> IO [PosLexToken]
runlexparser filename input =
    let result = parse lexparser filename input
    in case result of
         Left msg -> do print msg
                        fail "lexical error"

         Right tokens -> return tokens


run :: [String] -> IO ()
run args =
    do file <- readFile filename
       lex  <- runlexparser filename file
       if elem "-l" opts
          then printlex lex
          else return ()
       syn <- fmap ignorepos (runsynparser lex filename)
       if elem "-s" opts
          then printsyn syn
          else return ()

       checkedSyn <- return (runstaticanalyzer syn) -- [LUIS] Não entendi porque tem de por return aqui.
       if elem "-a" opts
          then printStaticAnalyzer checkedSyn
          else return ()

       if length opts == 0
          then case checkedSyn of 
                Right mod -> runinterpreter mod
                Left error -> putStrLn $ "Semantic error: " ++ error
          else return ()

    where isopt (c:cs) = c == '-'
          opts = filter isopt args
          filename = head (filter (not . isopt) args)


main :: IO ()
main = do putStrLn "<< PIG language interpreter >>"
          getArgs >>= run 
