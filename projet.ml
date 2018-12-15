#load "dynlink.cma";;
#load "camlp4/camlp4o.cma"

(** Environnement fonctionnel **)

type typage =
  | TBool of bool
  | TInt of int
             
type oper2 = 
  | Moins
  | Plus
  | Mul
  | Div
  | Ou
  | Et
  | Egal

type oper1 =
  | Non
  
type expr = 
  | Int of int
  | Op1 of oper1 * expr
  | Op2 of oper2 * expr * expr
  | Bool of bool
  | IfThenElse of expr * expr * expr 
  | LetIn of string * (string list) * expr * expr
  (* 
     nom : 
     paramètres : pour une variable classique, ce champ est []
     valeur : une expression
     suite :
  *)
  | Call of string * (expr list)

(* Un nom de variable est associé à une valeur *)
type env = (string * (string list) * expr) list


(* 
 *
 *)
let rec get (name : string) (e : env) =
  match e with
  |[] -> failwith "Identifieur inconnu"
  |(id,params,expr)::q -> if (id = name) then (params,expr) else (get name q)

let isInt (n : typage) = match n with
  |TInt(n) -> n
  |_ -> failwith "Incorrect type. Was expecting type Int"

let isBool (n : typage) = match n with
  |TBool(b) -> b
  | _ -> failwith "Incorrect type. Was expecting type Bool"

let egal e1 e2 =
  match e1, e2 with
  |TInt(n1),TInt(n2) -> (n1 == n2)
  |TBool(b1),TBool(b2) -> (b1 == b2)
  |_ -> failwith "Type mismatch during comparison"
       
(*
 * Pourquoi 2 environnements différents ?
 * Sinon pb avec => (fun y x -> ...)  appelé avec ( f x (y+3))
 *)
let rec load_params args params oldenv newenv =
  match args,params with
  |[],[] -> newenv@oldenv
  |[],_  -> failwith "Not enough arguments"
  |_ ,[] -> failwith "Too many arguments"
  |(a::qargs),(p::qparams) -> 
    let ev = (eval a oldenv) in
        begin
        match ev with
        | TInt(n) -> load_params qargs qparams oldenv ((p,[],Int(n))::newenv)
        | TBool(b) -> load_params qargs qparams oldenv ((p,[],Bool(b))::newenv)
        end
                  
and eval exp env =
  match exp with
  | Int n -> TInt(n)
  | Bool b -> TBool(b)
  | Op2 (Moins, x, y) -> TInt((isInt (eval x env)) - (isInt (eval y env)))
  | Op2 (Plus, x, y) -> TInt((isInt (eval x env)) + (isInt (eval y env)))
  | Op2 (Mul, x, y) -> TInt((isInt (eval x env)) * (isInt (eval y env)))
  | Op2 (Div, x, y) -> TInt((isInt (eval x env)) / (isInt (eval y env)))
  | Op2 (Ou, x, y) -> TBool((isBool (eval x env)) || (isBool (eval y env))) 
  | Op2 (Et, x, y) -> TBool((isBool (eval x env)) && (isBool (eval y env))) 
  | Op1 (Non, x) -> TBool(not (isBool (eval x env)))
  | Op2 (Egal, x, y) -> TBool(egal (eval x env) (eval y env))   
  | IfThenElse (cond,x,y) -> let a = (eval cond env) in let a2 = (isBool a) in (if a2 then (eval x env) else (eval y env))
  | Call(fname,pargs) -> let (params,fexpr) = (get fname env) in
                        let envf = (load_params pargs params env []) in
                        (eval fexpr envf) 
  | LetIn(name,params,expr,suite) ->  eval suite ((name,params,expr)::env)  
(*Evaluer les paramètres, les ajouter à l'environnement, evaluer l'identifieur v dans le nouvel environnement*)                                    
                 
let string_oper2 o =
  match o with
  | Moins -> "-"
  | Plus -> "+"
  | Mul -> "*"
  | Div -> "/"
  | Ou -> " | "
  | Et -> " & "
  | Egal -> " = "

let string_oper1 o =
  match o with
  | Non -> "!"

let rec print_strings p =
  match p with
  | [] -> print_string ""
  | x::l -> print_string x ; print_string " " ;print_strings l 

let rec print_exprs l =
  match l with
  |[] -> print_string ""
  |x::l -> print_expr x ; print_string " " ; print_exprs l 
and print_expr e =
  match e with
  | Int n -> print_int n
  | Bool b -> print_string (string_of_bool b)
  | Op2 (o, x, y) ->
     (print_char '(';
      print_expr x;
      print_string (string_oper2 o);
      print_expr y;
      print_char ')')
  | Op1 (o,x) ->
     (print_char '(';
      print_string (string_oper1 o);
      print_expr x;
      print_char ')')
  |IfThenElse (c,x,y) ->
     (print_string ("if ");
      print_expr c;
      print_string (" then {");
      print_expr x;
      print_string ("} else {");
      print_expr y;
      print_char '}')
  | LetIn (v,p,x,y) ->
     (print_string ("let ");
      print_string v;
      print_string (" = ");
      print_string "fun ";
      print_strings p ;
      print_string "-> " ;
      print_expr x ;
      print_string (" in ");
      print_expr y)
  | Call(v,p) ->
      print_string v;
      print_string " ";
      print_exprs p
    
      (* FLOTS *)

(* Pour le test *)
let rec list_of_stream = parser
  | [< 'x; l = list_of_stream >] -> x :: l
  | [< >] -> []

(* ANALYSEUR LEXICAL sur un flot de caractères *)
	      
(* Schéma de Horner *)
let chiffre = parser  [<'  '0'..'9' as x >] -> x

let valchiffre c = int_of_char c - int_of_char '0'
let rec horner n = parser 
  | [< c = chiffre ; s >] -> horner (10 * n + valchiffre c) s
  | [< >] -> n

let lettre = parser  [< ''a'..'z' | 'A'..'Z' as x >] -> x  
let alphanum = parser
  | [< x = lettre >] -> x
  | [< x = chiffre >] -> x

let rec lettres = parser
  | [<  x = alphanum; l = lettres >] -> x::l;
  | [< >] -> []

let rec lettres_to_bytes (l : char list) (i : int) (b : bytes) : string =
  match l with
  | []   -> Bytes.to_string b
  | x::q -> Bytes.set b i x ; lettres_to_bytes q (i+1) b  

let ident = parser
  | [< c = lettre ; l = lettres>] -> 
  let b = Bytes.make ((List.length l)+1) c in
  (lettres_to_bytes l 1 b)

(* Type des lexèmes *)
type token = 
  | Tent of int
  | Tmoins
  | Tplus
  | Tparouvre
  | Tparferme
  | Tmul
  | Tdiv
  | Tbool of bool  
  | Tou
  | Tet
  | Tnon
  | Tsi
  | Tsinon
  | Talors
  | Tegal
  | Tident of string
  | Tsoit
  | Tdans
  | Tfun
  | Tfleche
  | Tparam of string list
(* 
Pour passer d'un flot de caractères à un flot de lexèmes,
on commence par une fonction qui analyse lexicalement les
caractères d'un lexème au début d'un flot de caractères.
La fonction next_token rend un token option, c'est-à-dire :
- soit Some (tk)   où tk est un token
  dans le cas où le début du flot correspond lexème
- soit None

Le type option est prédéfini ainsi dans la bibliothèque standard OCaml :
type 'a option =
  | None           (* indique l'absence de valeur *)
  | Some of 'a     (* indique la présence de valeur *)
*)
            
let id_to_token id =
  match id with
  | "vrai" -> Tbool(true)
  | "faux" -> Tbool(false)
  | "non" -> Tnon
  | "si" -> Tsi
  | "alors" -> Talors
  | "sinon" -> Tsinon
  | "soit" -> Tsoit
  | "dans" -> Tdans
  | "fun" -> Tfun
  | str -> Tident(str) 

let rec next_token = parser
  | [< '  ' '|'\n'; tk = next_token >] -> tk (* élimination des espaces *)
  | [< '  '0'..'9' as c; n = horner (valchiffre c) >] -> Some (Tent (n))
  | [< '  '~';'  '>'>] -> Some (Tfleche)
  | [< '  '-' >] -> Some (Tmoins)
  | [< '  '+' >] -> Some (Tplus)
  | [< '  '(' >] -> Some (Tparouvre)
  | [< '  ')' >] -> Some (Tparferme)
  | [< '  '*' >] -> Some (Tmul)
  | [< '  '/' >] -> Some (Tdiv)
  | [< '  '=' >] -> Some (Tegal)
  | [< '  '&'; '  '&'>] -> Some (Tet)
  | [< '  '|'; '  '|'>] -> Some (Tou)
  | [< s = ident >] -> Some (id_to_token s)
  | [< >] -> None

(* tests *)
let s = Stream.of_string "soit f = fun x ~> x * x dans f 2"
let tk1 = next_token s
let tk2 = next_token s
let tk3 = next_token s
let tk4 = next_token s
let tk5 = next_token s
let tk6 = next_token s
let _ = next_token s

      
(* L'analyseur lexical parcourt récursivement le flot de caractères s
   en produisant un flot de lexèmes *)
let rec tokens s =
  match next_token s with
  | None -> [< >]
  | Some tk -> [< 'tk; tokens s >]

let lex s = tokens s

(* tests *)
let s = Stream.of_string "soit f = fun x -> x*x dans f 2"
let stk = lex s
let ltk = list_of_stream stk  

(*
Alternativement, la primitive Stream.from conduit au même résultat,
on l'utilise comme ci-dessous.
*)

let lex s = Stream.from (fun _ -> next_token s)

(*
A savoir : cette dernière version repose sur une représentation
interne des flots beaucoup plus efficace. Pour plus de détails
sur Stream.from, consulter le manuel OCaml.
Dans un compilateur réaliste devant traiter de gros textes, 
c'est la version à utiliser.
*)

let ltk1 = list_of_stream (lex (Stream.of_string "356 - 10 - 4"))

(* ANALYSEUR SYNTAXIQUE sur un flot de lexèmes *)

(* A noter : le passage d'un argument de type expr pour obtenir le
   bon parenthèsage de l'expression :
   41 - 20 - 1 est compris comme (41 - 20) - 1, non pas 41 - (20 - 1)
*)
let rec p_expr = parser
     | [< 'Tsi ; e1 = p_expr ; 'Talors ; e2 = p_expr ; 'Tsinon ; e3 = p_expr >] -> IfThenElse (e1,e2,e3)
     | [< 'Tsoit ; 'Tident(v) ; 'Tegal ; (p,x) = p_fun ; 'Tdans ; e1 = p_expr >] -> LetIn(v,p,x,e1)
     | [< c = p_conj ; sd = p_s_disj c >] -> sd
and p_fun = parser
     | [< 'Tfun ; p = p_param ; 'Tfleche ; x = p_expr>] -> (p,x)
     | [< e = p_expr>] -> ([],e)
and p_param = parser
     | [< 'Tident(x) ; l = p_param>] -> x::l
     | [< >] -> []
and p_s_disj c = parser
     | [< 'Tou ; p = p_conj ; sd = p_s_disj (Op2(Ou,c,p))>] -> sd
     | [< >] -> c
and p_conj = parser
     | [< l = p_litt ; c = p_s_conj l>] -> c
and p_s_conj c = parser
     | [< 'Tet ; p = p_litt ; sc = p_s_conj (Op2(Et,c,p)) >] -> sc
     | [< >] -> c           
and p_litt = parser
     | [< 'Tnon ; p = p_litt>] -> Op1(Non,p)
     | [< ec = p_expr_comp; cmp = p_comp ec >] -> cmp
and p_comp e = parser
     |[< 'Tegal ; ec = p_expr_comp>] -> (Op2(Egal,e,ec))
     |[< >] -> e
and p_expr_comp = parser
     | [< t = p_terme; e = p_s_add t >] -> e
and p_s_add a = parser 
     | [< ' Tmoins; t = p_terme; e = p_s_add (Op2(Moins,a,t)) >] -> e
     | [< ' Tplus; t = p_terme; e = p_s_add (Op2(Plus,a,t)) >] -> e
     | [< >] -> a
and p_terme = parser
     | [< f = p_fact; sm = p_s_mul f >] -> sm
and p_s_mul a = parser
     | [< ' Tmul; t = p_fact; e = p_s_mul (Op2(Mul,a,t)) >] -> e
     | [< ' Tdiv; t = p_fact; e = p_s_mul (Op2(Div,a,t)) >] -> e
     | [< >] -> a
and p_s_expr = parser
     | [<x = p_expr ; l = p_s_expr>] -> x::l
     | [< >] -> []
and p_fact = parser
     | [< ' Tent(n)>] -> Int(n)
     | [< ' Tparouvre ; exp = p_expr; ' Tparferme>] -> exp
     | [< ' Tbool(b) >] -> Bool(b)
     | [< ' Tident(v) ; se = p_s_expr>] -> Call(v,se)
                         
let ast s = p_expr (lex (Stream.of_string s));;

let e1 = ast "soit f = fun x y ~> x * y dans f 3 4 + 3";;
let _ = eval e1 [];;

let _ = print_expr e1;;


let test1 = ast "soit x = 5 dans x + (soit x = 2 dans x) - x";;
let _ = eval test1 [];;

let test2 = ast "soit x = 5 dans (soit y = 2 dans x + y)";;
let _ = eval test2 [];;

let test3 = ast "si vrai alors 2 sinon 3";;
let _ = print_expr test3;;
let _ = eval test3 [];;

let test4 = ast "soit x = 5 dans si faux alors si vrai || faux alors vrai sinon faux sinon x";;
let _ = print_expr test4;;
let _ = eval test4 [];;
          
let test5 = ast "soit x = 5 dans x + (si vrai && faux || vrai alors 3 sinon 2)";;
let _ = print_expr test5;;
let _ = eval test5 [];;

let test6 = ast "soit x = 4 dans x + (si vrai alors soit x = 4 dans x sinon (si faux alors soit x = 2 dans x sinon soit x = 3 dans x))"
let _ = print_expr test6;;
let _ = eval test6 [];;

let test7 = ast "soit var = 42 dans var + (soit vra1 = 2 dans vra1)";;
let _ = print_expr test7;;
let _ = eval test7 [];;

let test8 = ast "soit var1 = 4 dans var1 + (si non vrai alors soit var2 = 1 dans var2 sinon soit var3 = 2 dans var3)";;
let _ = print_expr test8;;
let _ = eval test8 [];;

let test9 = ast "non non non non vrai";;
let _ = print_expr test9;;
let _ = eval test9 [];;

let test10 = ast "soit x = 10 dans x * (si non non vrai && non faux alors soit y = 5 dans y sinon (si vrai && non non faux alors soit z = 8 dans z sinon soit w = 4 dans w))";;
let _ = print_expr test10;;
let _ = eval test10 [];;

let x = 5 in x + (if true && false || true then 3 else 2);;
let x = 4 in x + (if true then let x = 4 in x else (if false then let x = 2 in x else let x = 3 in x));;
let x = 10 in x*(if (not (not true)) && not false then let y = 5 in y else (if true && (not (not false)) then let z = 8 in z else let w = 4 in w));;

let t42 = ast "si 2 alors vrai sinon faux"
let _ = eval t42 []
