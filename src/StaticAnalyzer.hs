module StaticAnalyzer where

import Syntactic
import PosParsec(ignorepos, Located)
import Types

--------------------------------------
--------- Build symbol table ---------
--------------------------------------
-- This function traverses the syntactic tree
-- building the symbol table. It searches for
-- definitions of all kinds - SynDef, SynFunc, 
-- SynProc, SynStruct - then builds a list of
-- identifiers altogether with its type (and 
-- any other information that might be useful).
data STEntry = Variable { getVarId :: String    -- identifier
                        , getVarType :: String  -- type
                        , getVarMod :: String }  -- module where it was defined 
             | Function { getFuncName :: String
                        , getFuncArgTypes :: [String]
                        , getFuncRetTypes :: [String]
                        , getFuncMod :: String } 
             | Procedure { getProcName :: String
                         , getProcArgTypes :: [String]
                         , getProcMod :: String} deriving (Show)

type SymbolTable = [STEntry]

data Field = Field { getFieldName :: String
                   , getFieldType :: String } deriving (Show)

data UTEntry = StructEntry { getStructName :: String     -- Type name
                          , getStructFields :: [Field]  -- List of fields defined inside this struct
                          , getStructMod :: String }     -- module where it was defined
             | Primitive { getPrimName :: String } deriving (Show)

typeTable :: UserTypeTable
typeTable = [ Primitive "int"
            , Primitive "float"
            , Primitive "bool"
            , Primitive "vec"
            , Primitive "vec2"
            , Primitive "vec3"
            , Primitive "vec4"
            , Primitive "mat"
            , Primitive "mat2"
            , Primitive "mat3"
            , Primitive "mat4"]

type UserTypeTable = [UTEntry]

type SuperTable = (SymbolTable, UserTypeTable)

-- TODO: We should receive a SynProgram, which is
-- itself a set of SynModules
stFromModule :: SuperTable -> SynModule -> Either String SuperTable 
stFromModule st ( SynModule id stmts ) = stFromModStmts st (getlabel $ ignorepos id) stmts 

stFromModStmts :: SuperTable -> String -> [SynModStmt] -> Either String SuperTable
stFromModStmts st id [] = Right st
stFromModStmts st id (h:t) = let result = stFromModStmt st id h in
                             case result of
                                Left errorMsg  -> Left errorMsg
                                Right newSt -> stFromModStmts newSt id t


stFromModStmt :: SuperTable -> String -> SynModStmt -> Either String SuperTable
stFromModStmt st id s = case s of
                            (SynModStruct stct) -> stFromStruct st id (ignorepos stct)
                            (SynModDef def) -> stFromDef st id (ignorepos def)
                            (SynModProc proc) -> stFromProc st id (ignorepos proc)
                            (SynModFunc func) -> stFromFunc st id (ignorepos func)

stFromStruct :: SuperTable -> String -> SynStruct -> Either String SuperTable 
stFromStruct st modid stct = let n = getlabel $ ignorepos $ getSynStructName stct in
                                if isElemUserTypeTable n modid (snd st) || isElemSymbolTable n modid (fst st)
                                  then Left "Name already being used as a type name or variable name."
                                  else Right (fst st, newTypeTable)
                                      where newTypeTable = newEntry : (snd st)
                                            newEntry = StructEntry (getlabel $ ignorepos $ getSynStructName stct)
                                                                   ([])
                                                                   modid

{-
stFieldsFromTypedIdent :: [SynTypedIdent] -> [Field]
stFieldsFromTypedIdent [] = []
stFieldsFromTypedIdent (h:t) = field : (stFieldsFromTypedIdent t)
                                where field = Field (getlabel $ ignorepos getTypedIdentName h)
                                                    (getTypedIdentType h)
-}

stFromDef :: SuperTable -> String -> SynDef -> Either String SuperTable
stFromDef st modid (SynDef typedId) = stFromTypedIdentList st modid typedId

stFromProc :: SuperTable -> String -> SynProc -> Either String SuperTable
stFromProc st modid (SynProc name formalParam block) = let n = getlabel $ ignorepos name in
                                                          if isElemUserTypeTable n modid (snd st) || isElemSymbolTable n modid (fst st)
                                                            then Left "Name already being used as a type name or variable name."
                                                            else Right (syt, (snd st))
                                                                where syt = entry : (fst st)
                                                                      entry = Procedure (getlabel $ ignorepos name)
                                                                                        (buildProcTypeStr formalParam)
                                                                                        modid  

stFromFunc :: SuperTable -> String -> SynFunc -> Either String SuperTable
stFromFunc st modid (SynFunc name formalParam ret block) = let n = getlabel $ ignorepos name in
                                                              if isElemUserTypeTable n modid (snd st) || isElemSymbolTable n modid (fst st)
                                                                then Left "Name already being used as a type name or variable name."
                                                                else Right (syt, (snd st))
                                                                        where syt = entry : (fst st)
                                                                              entry = Function (getlabel $ ignorepos name)
                                                                                               (buildFuncArgTypeList formalParam)
                                                                                               (buildFuncRetTypeList ret)
                                                                                               modid

buildFuncArgTypeList :: [SynTypedIdent] -> [String]
buildFuncArgTypeList formalParam = (getlabel . ignorepos . getTypeIdent . ignorepos . getTypedIdentType) `fmap` formalParam
                                        
buildFuncRetTypeList :: [SynTypedIdent] -> [String]
buildFuncRetTypeList ret = (getlabel . ignorepos . getTypeIdent . ignorepos . getTypedIdentType) `fmap` ret

buildProcTypeStr :: [SynTypedIdent] -> [String]
buildProcTypeStr formalParam = (getlabel . ignorepos . getTypeIdent . ignorepos . getTypedIdentType) `fmap` formalParam


-- TODO: Code for entry is to big; maybe we could create some 
-- helper functions to make it smaller.
stFromTypedIdentList :: SuperTable -> String -> [SynTypedIdent] -> Either String SuperTable
stFromTypedIdentList st modid [] = Right st
stFromTypedIdentList st modid (h:t) = let name = getlabel $ ignorepos $ getTypedIdentName h in
                                        if isElemUserTypeTable name modid (snd st) || isElemSymbolTable name modid (fst st)
                                            then Left "Name already being used as a type name or variable name." 
                                            else stFromTypedIdentList (newST, snd st) modid t
                                                  where newST = entry : (fst st)
                                                        entry = Variable (getlabel $ ignorepos $ getTypedIdentName h) 
                                                                         (getLabelFromType $ ignorepos $ getTypedIdentType h) 
                                                                         modid 

isElemUserTypeTable :: String -> String -> [UTEntry] -> Bool
isElemUserTypeTable s m [] = False
isElemUserTypeTable s m (h:t) = case h of 
                                StructEntry name _ modid -> if modid == m && name == s 
                                                              then True
                                                              else isElemUserTypeTable s m t 
                                Primitive name -> if name == s
                                                    then True
                                                    else isElemUserTypeTable s m t

isElemSymbolTable :: String -> String -> [STEntry] -> Bool
isElemSymbolTable s m [] = False
isElemSymbolTable s m (h:t) = case h of 
                                Variable name _ modid -> if modid == m && name == s 
                                                          then True
                                                          else isElemSymbolTable s m t 
                                Function name _ _ modid -> if modid == m && name == s
                                                          then True
                                                          else isElemSymbolTable s m t
                                Procedure name _ modid -> if modid == m && name == s
                                                            then True
                                                            else isElemSymbolTable s m t

-----------------------------------
--------- Static analyzer --------- TODO: Move this to another file when 
-----------------------------------       things get more structured.

{- DROPPED. This is not useful anymore, as certainly
    we'll have only one rule for modules. This idea for
    chaining rules is "good", though, so I'll leave it
    here so I can copy/paste it someday.

-- This applies all the static semantic rules to x.
-- Notice this will apply rules in inverse order, but
-- we assume them to be commutative somehow (that is,
-- order of verification should not be important).
semModule' :: [SynModule -> Either String SynModule] -> SynModule -> Either String SynModule
semModule' [] x = Right x
semModule' (rule:tail) x  = (semModule' tail x) >>= rule -}

-- Checking rules: each of these rules check SynStuff for
-- soundness (according to soundness rules of each syntactic construct).
-- The general idea is: the soundness of a syntactic construct
-- depends on the soundness of what constitutes it; hence, when we have
-- a syntactic unit S -> s1 s2 s3 ..., we check each syntactic subunit
-- s1, s2, s3. If all of them are sound (i.e., all of them return RIGHT),
-- we can say that S itself is sound. If any rule is wrong, 'though (i.e.,
-- returns a LEFT), we say that S is also wrong and we forward the message
-- inside LEFT.
--
-- IDEA: What if each Syn___ was instance of some Checkable typeclass,
-- which is itself a monad, so we could chain Checkable stuff together?
-- Would this eliminate all of those case blabla?
--
-- IDEA: Maybe we could chain the error messages to say something like
-- "In module x, in func ___, in statement ___ : blablabla", just as
-- Haskell compiler does.
--
checkMod :: SynModule -> Either String SynModule
checkMod sm@(SynModule id stmts) = case stFromModule ([], typeTable) sm of
                                    Left msg -> Left msg
                                    Right st -> case checkModStmts st stmts of
                                                  Right _ -> Right (SynModule id stmts)
                                                  Left msg -> Left msg

checkModStmts :: SuperTable -> [SynModStmt] -> Either String [SynModStmt]
checkModStmts st [] = Right []
checkModStmts st (stmt:tail) = case checkedStmt of
                            Left msg -> Left msg
                            Right _ -> do x <- checkedStmt
                                          y <- checkModStmts st tail
                                          Right (x : y)
                          where checkedStmt = checkModStmt st stmt

checkModStmt :: SuperTable -> SynModStmt -> Either String SynModStmt
checkModStmt st stmt = case stmt of
                  SynModStruct ss -> Right stmt    -- No rule for structs nor def's (so far)
                  SynModDef sd -> Right stmt
                  SynModProc sp -> case checkProc st sp of
                                      Right _ -> Right stmt
                                      Left msg -> Left msg
                  SynModFunc sf -> checkFunc st sf

checkFunc :: SuperTable -> Located SynFunc -> Either String SynModStmt -- PENDING
checkFunc st func = Right $ SynModFunc func 

checkProc :: SuperTable -> Located SynProc -> Either String SynProc
checkProc st proc = case checkBlock st $ getProcBlock unlocProc of
                    Right _ -> Right unlocProc
                    Left msg -> Left msg
                  where unlocProc = ignorepos proc

checkBlock :: SuperTable -> Located SynBlock -> Either String SynBlock
checkBlock st block = case checkedStmts of
                      Right _ -> Right $ ignorepos block
                      Left msg -> Left msg
                    where checkedStmts = checkStmts st $ ignorepos `fmap` getStmts (ignorepos block)

checkStmts :: SuperTable -> [SynStmt] -> Either String [SynStmt]
checkStmts st [] = Right []
checkStmts st (stmt:tail) = case checkedStmt of
                            Left msg -> Left msg
                            Right _ -> do h <- checkedStmt
                                          t <- checkStmts st tail
                                          Right (h:t)
                          where checkedStmt = checkStmt st stmt

checkStmt :: SuperTable -> SynStmt -> Either String SynStmt -- PENDING
checkStmt st s = case s of
                SynStmtDef sd -> Right s
                SynStmtAttr sa -> let a@(SynAttr l1 l2) = ignorepos sa in
                                    if length l1 /= length l2
                                      then Left "Different number of identifiers and expressions in attribution."
                                      else case (checkAttr st a) of
                                              Left msg -> Left msg
                                              Right _ -> Right s 
                SynStmtDefAttr sda -> Right s
                SynStmtIf si -> Right s
                SynStmtWhile sw -> Right s
                SynStmtCall sc -> Right s

--trocar: naao é s1 == s2, levar em conta o "_" 
checkAttr :: SuperTable -> SynAttr -> Either String SynAttr
checkAttr st sa@(SynAttr si se) = case buildIdentTypeList st (ignorepos `fmap` si) of
                                    Left msg -> Left msg
                                    Right s1 -> case buildExprTypeList st (ignorepos `fmap` se) of
                                                  Left msg -> Left msg
                                                  Right s2 -> if s1 == s2
                                                                then Right sa
                                                                else Left "Variable and expression have different types in attribution."
           
buildIdentTypeList :: SuperTable -> [SynIdent] -> Either String [String]
buildIdentTypeList st [] = Right []
buildIdentTypeList st (h:t) = case identType st h of
                                Left msg -> Left msg
                                Right s -> case buildIdentTypeList st t of
                                            Left msg -> Left msg
                                            Right l -> Right $ s : l

buildExprTypeList :: SuperTable -> [SynExpr] -> Either String [String]
buildExprTypeList st [] = Right []
buildExprTypeList st (h:t) = case checkExpr st h of
                                Left msg -> Left msg
                                Right s -> case buildExprTypeList st t of
                                            Left msg -> Left msg
                                            Right l -> Right $ s ++ l

identType :: SuperTable -> SynIdent -> Either String String
identType (syt, utt) si@(SynIdent s) = case t1 of
                                        Right vtype -> Right vtype
                                        Left _ -> case t2 of
                                                        Right ftype -> Right ftype
                                                        Left msg -> Left msg
                                      where t1 = searchSymbolTable syt s
                                            t2 = searchUserTypeTable utt s

searchSymbolTable :: [STEntry] -> String -> Either String String
searchSymbolTable [] s = Left "Variable not defined."
searchSymbolTable (h:t) s = case h of 
                                Variable name vtype _ -> if name == s
                                                          then Right vtype
                                                          else searchSymbolTable t s
                                _ -> searchSymbolTable t s

-- search for the type of the variable in a struct
searchUserTypeTable :: [UTEntry] -> String -> Either String String
searchUserTypeTable utt s = Left "Variable not defined."

checkExpr :: SuperTable -> SynExpr -> Either String [String]
checkExpr st se = case se of
                  SynIdentExpr e -> case identType st $ ignorepos e of
                                      Left msg -> Left msg
                                      Right vtype -> Right $ vtype : []
                  SynLitIntExpr _ -> Right $ "int" : []
                  SynLitFloatExpr _ -> Right $ "float" : []
                  SynLitBoolExpr _ -> Right $ "bool" : []
                  SynCallExpr e -> case findFuncRetTypes (fst st) $ getlabel $ ignorepos $ getFuncId $ ignorepos e of
                                      Left msg -> Left msg
                                      Right ftype -> Right ftype
                  SynPar e -> checkExpr st $ ignorepos e
                  SynNeg e -> case checkExpr st $ ignorepos e of
                                Left msg -> Left msg
                                Right l -> if l == ["int"] || l == ["float"]
                                              then Right l
                                              else Left "Operator '-' (unary) expects an operand of type int or float."
                  SynBitNot e -> case checkExpr st $ ignorepos e of
                                Left msg -> Left msg
                                Right l -> if l == ["int"]
                                            then Right l
                                            else Left "Operator '!' expects an operand of type int."
                  SynNot e -> case checkExpr st $ ignorepos e of
                                Left msg -> Left msg
                                Right l -> if l == ["bool"]
                                            then Right l
                                            else Left "Operator 'not' expects an operand of type bool."
                  SynExp e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "Operator '^' expects operands of equal types."
                                                                        else Left "Operator '^' expects operands of type int or float."
                                                  else Left "Operator '^' expects operands of type int or float."
                  SynTimes e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "If the first operand is of type int or float, operator '*' expects second operator of same type."
                                                                        else Left "If the first operand is of type int or float, operator '*' expects second operator of type int or float."
                                                  else if l1 == ["vec"] || l1 == ["vec2"] || l1 == ["vec3"] || l1 == ["vec4"] 
                                                          then case checkExpr st $ ignorepos e2 of
                                                                  Left msg -> Left msg
                                                                  Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                                then Right l1
                                                                                else if l2 == ["mat"] || l2 == ["mat2"] || l2 == ["mat3"] || l2 == ["mat4"]
                                                                                        then Right ["vec"]
                                                                                        else Left "Operands of wrong types."
                                                          else if l1 /= ["bool"]
                                                                  then case checkExpr st $ ignorepos e2 of
                                                                        Left msg -> Left msg
                                                                        Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                                      then Right l1
                                                                                      else if l2 == ["vec"] || l2 == ["vec2"] || l2 == ["vec3"] || l2 == ["vec4"] 
                                                                                              then Right ["mat"]
                                                                                              else Left "Operands of wrong types."
                                                                  else Left "Operator '*' expects operands of type int, float, vec or mat."
                  SynDiv e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "If the first operand is of type int or float, operator '/' expects second operator of same type."
                                                                        else Left "If the first operand is of type int or float, operator '/' expects second operator of type int or float."
                                                  else if l1 /= ["bool"]
                                                          then case checkExpr st $ ignorepos e2 of
                                                                  Left msg -> Left msg
                                                                  Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                                then Right l1 
                                                                                else Left "If the first operand is of type vec or mat, operator '/' expects second operator of type int or float."
                                                          else Left "Operator '/' expects operands of type int, float, vec or mat."
                  SynMod e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "Operator 'mod' expects operands of equal types."
                                                                        else Left "Operator 'mod' expects operands of type int or float."
                                                  else Left "Operator 'mod' expects operands of type int or float."
                  SynPlus e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 /= ["bool"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 /= ["bool"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "Operator '+' expects operands of equal types."
                                                                        else Left "Operator '+' expects operands of type int, float, vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                                                  else Left "Operator '+' expects operands of type int, float, vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                  SynMinus e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 /= ["bool"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 /= ["bool"]
                                                                        then if l1 == l2
                                                                                then Right l1
                                                                                else Left "Operator '-' (binary) expects operands of equal types."
                                                                        else Left "Operator '-' (binary) expects operands of type int, float, vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                                                  else Left "Operator '-' (binary) expects operands of type int, float, vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                  SynDotTimes e1 e2 -> case checkExpr st $ ignorepos e1 of
                                        Left msg -> Left msg
                                        Right l1 -> if l1 /= ["int"] && l1 /= ["float"] && l1 /= ["bool"]
                                                      then case checkExpr st $ ignorepos e2 of
                                                              Left msg -> Left msg
                                                              Right l2 -> if l2 /= ["int"] && l2 /= ["float"] && l2 /= ["bool"]
                                                                            then if l1 == l2
                                                                                    then Right l1
                                                                                    else Left "Operator '.*.' expects operands of equal types."
                                                                            else Left "Operator '.*.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                                                      else Left "Operator '.*.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                  SynDotDiv e1 e2 -> case checkExpr st $ ignorepos e1 of
                                        Left msg -> Left msg
                                        Right l1 -> if l1 /= ["int"] && l1 /= ["float"] && l1 /= ["bool"]
                                                      then case checkExpr st $ ignorepos e2 of
                                                              Left msg -> Left msg
                                                              Right l2 -> if l2 /= ["int"] && l2 /= ["float"] && l2 /= ["bool"]
                                                                            then if l1 == l2
                                                                                    then Right l1
                                                                                    else Left "Operator './.' expects operands of equal types."
                                                                            else Left "Operator './.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                                                      else Left "Operator './.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                  SynDot e1 e2 -> case checkExpr st $ ignorepos e1 of
                                        Left msg -> Left msg
                                        Right l1 -> if l1 /= ["int"] && l1 /= ["float"] && l1 /= ["bool"]
                                                      then case checkExpr st $ ignorepos e2 of
                                                              Left msg -> Left msg
                                                              Right l2 -> if l2 /= ["int"] && l2 /= ["float"] && l2 /= ["bool"]
                                                                            then if l1 == l2
                                                                                    then Right l1
                                                                                    else Left "Operator '.' expects operands of equal types."
                                                                            else Left "Operator '.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                                                      else Left "Operator '.' expects operands of type vec, vec2, vec3, vec4, mat, mat2, mat3 or mat4."
                  SynRShift e1 e2 -> Left ""
                  SynLShift e1 e2 -> Left ""
                  SynBitAnd e1 e2 -> Left ""  
                  SynBitXor e1 e2 -> Left ""  
                  SynBitOr e1 e2 -> Left "" 
                  SynEQ e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l1 == l2
                                                                        then Right ["bool"]
                                                                        else Left "Operator '==' expects operands of equal types." 
                  SynNEQ e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l1 == l2
                                                                        then Right ["bool"]
                                                                        else Left "Operator '=/=' expects operands of equal types." 
                  SynLT e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right ["bool"]
                                                                                else Left "Operator '<' expects operands of equal types."
                                                                        else Left "Operator '<' expects operands of type int or float."
                                                  else Left "Operator '<' expects operands of type int or float."    
                  SynLE e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right ["bool"]
                                                                                else Left "Operator '<=' expects operands of equal types."
                                                                        else Left "Operator '<=' expects operands of type int or float."
                                                  else Left "Operator '<=' expects operands of type int or float."     
                  SynGT e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right ["bool"]
                                                                                else Left "Operator '>' expects operands of equal types."
                                                                        else Left "Operator '>' expects operands of type int or float."
                                                  else Left "Operator '>' expects operands of type int or float."    
                  SynGE e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["int"] || l1 == ["float"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["int"] || l2 == ["float"]
                                                                        then if l1 == l2
                                                                                then Right ["bool"]
                                                                                else Left "Operator '>=' expects operands of equal types."
                                                                        else Left "Operator '>=' expects operands of type int or float."
                                                  else Left "Operator '>=' expects operands of type int or float."  
                  SynAnd e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["bool"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["bool"]
                                                                        then Right l1
                                                                        else Left "Operator 'and' expects operands of type bool."
                                                  else Left "Operator 'and' expects operands of type bool."  
                  SynXor e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["bool"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["bool"]
                                                                        then Right l1
                                                                        else Left "Operator 'xor' expects operands of type bool."
                                                  else Left "Operator 'xor' expects operands of type bool."  
                  SynOr e1 e2 -> case checkExpr st $ ignorepos e1 of
                                    Left msg -> Left msg
                                    Right l1 -> if l1 == ["bool"]
                                                  then case checkExpr st $ ignorepos e2 of
                                                          Left msg -> Left msg
                                                          Right l2 -> if l2 == ["bool"]
                                                                        then Right l1
                                                                        else Left "Operator 'or' expects operands of type bool."
                                                  else Left "Operator 'or' expects operands of type bool."    
                  

findFuncRetTypes :: [STEntry] -> String -> Either String [String]
findFuncRetTypes [] s = Left "Function not defined."
findFuncRetTypes (h:t) s = case h of
                            Function name _ list _ -> if name == s
                                                        then Right list
                                                        else findFuncRetTypes t s
                            Procedure name _ _ -> if name == s
                                                    then Left "Can't call a procedure in an attribution (no return value)."
                                                    else findFuncRetTypes t s
                            Variable name _ _ -> if name == s
                                                    then Left "Function not defined." 
                                                    else findFuncRetTypes t s




