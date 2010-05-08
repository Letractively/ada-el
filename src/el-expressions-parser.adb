-----------------------------------------------------------------------
--  Parser -- Parser for Expression Language
--  Copyright (C) 2009, 2010 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------

with Ada.Characters.Conversions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.Unbounded;
with EL.Functions;
package body EL.Expressions.Parser is

   use Ada.Characters.Conversions;
   use Ada.Strings.Wide_Wide_Unbounded;
   use Ada.Strings.Unbounded;

   use EL.Expressions.Nodes;
   use EL.Functions;

   type Token_Type is (T_EOL,
                       T_LEFT_PARENT,
                       T_RIGHT_PARENT,
                       T_LT, T_LE, T_GT, T_GE, T_NE, T_EQ, T_EMPTY,
                       T_NOT,
                       T_OR, T_AND, T_LOGICAL_AND,
                       T_MINUS, T_PLUS, T_MUL, T_Div, T_MOD, T_DOT,
                       T_QUESTION, T_COLON, T_COMMA,
                       T_NUMBER, T_LITERAL, T_NAME,
                       T_TRUE, T_FALSE, T_NULL,
                       T_UNKNOWN);

   type Parser is record
      Pos  : Natural;
      Last : Natural;
      Token_Start : Natural;
      Token_End   : Natural;
      Expr : access Wide_Wide_String;
      Token : Unbounded_Wide_Wide_String;
      Value : Long_Long_Integer;
      Pending_Token : Token_Type := T_EOL;
      Mapper : Function_Mapper_Access;
   end record;

   function To_Unbounded_String (Str : Unbounded_Wide_Wide_String)
     return Unbounded_String;

   procedure Put_Back (P : in out Parser; Token : in Token_Type);

   procedure Parse_Choice (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Or (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_And (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Equality (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Compare (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Math (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Multiply (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Unary (P : in out Parser; Result : out ELNode_Access);
   procedure Parse_Function (P         : in out Parser;
                             Namespace : in Unbounded_String;
                             Name      : in Unbounded_String;
                             Result    : out ELNode_Access);

   --  Parse the expression buffer to find the next token.
   procedure Peek (P : in out Parser; Token : out Token_Type);
   procedure Parse_Number (P      : in out Parser;
                           Result : out Long_Long_Integer);

   function To_Unbounded_String (Str : Unbounded_Wide_Wide_String)
                                 return Unbounded_String is
   begin
      return To_Unbounded_String (To_String (To_Wide_Wide_String (Str)));
   end To_Unbounded_String;

   --  #{bean.name}
   --  #{12 + 23}
   --  #{bean.name + bean.name}
   --  #{bean.name == 2 ? 'test' : 'foo'}
   --
   --  expr ::= expr ? expr : expr
   --  expr ::= expr <op> expr
   --  expr ::= <unary> expr
   --  expr ::= ( expr )
   --  expr ::= expr ? expr : expr
   --  expr ::= name . name
   --  expr ::= name
   --  expr ::= <number>
   --  expr ::= <literal>
   --  literal ::= '...' | ".."
   --  number ::= [0-9]+
   --

   --  Parse a choice expression, then Or.
   --
   --  choice ::= expr '?' expr ':' choice
   --
   procedure Parse_Choice (P : in out Parser;
                            Result : out ELNode_Access) is
      Cond, Left, Right : ELNode_Access;
      Token : Token_Type;
   begin
      Parse_Or (P, Cond);
      Peek (P, Token);
      if Token /= T_QUESTION then
         Put_Back (P, Token);
         Result := Cond;
         return;
      end if;
      Parse_Or (P, Left);
      Peek (P, Token);
      if Token /= T_COLON then
         raise Invalid_Expression with "Missing :";
      end if;
      Parse_Choice (P, Right);
      Result := Create_Node (Cond, Left, Right);
   end Parse_Choice;

   --  Parse a logical 'or' expression, then 'and'
   --
   --  or-expr ::= and-expr || and-expr
   procedure Parse_Or (P      : in out Parser;
                       Result : out ELNode_Access) is
      Token : Token_Type;
      Left, Right : ELNode_Access;
   begin
      Parse_And (P, Left);
      loop
         Peek (P, Token);
         exit when Token /= T_OR;
         Parse_And (P, Right);
         Left := Create_Node (EL_LOR, Left, Right);
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_Or;

   --  Parse a logical 'and' expression, then 'equality'
   --
   --  and-expr ::= equ-expr && equ-expr
   procedure Parse_And (P     : in out Parser;
                       Result : out ELNode_Access) is
      Token : Token_Type;
      Left, Right : ELNode_Access;
   begin
      Parse_Equality (P, Left);
      loop
         Peek (P, Token);
         exit when Token /= T_LOGICAL_AND;
         Parse_Equality (P, Right);
         Left := Create_Node (EL_LAND, Left, Right);
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_And;

   --  Parse an equality '==' 'eq' '!=' 'ne expression, then 'compare'
   --
   --  equ-expr ::= cmp-expr '==' cmp-expr
   --  equ-expr ::= cmp-expr '!=' cmp-expr
   procedure Parse_Equality (P      : in out Parser;
                             Result : out ELNode_Access) is
      Token : Token_Type;
      Left, Right : ELNode_Access;
   begin
      Parse_Compare (P, Left);
      loop
         Peek (P, Token);
         exit when Token /= T_EQ and Token /= T_NE;
         Parse_Equality (P, Right);
         Left := Create_Node (EL_LAND, Left, Right);
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_Equality;

   --  Parse a comparison operation then Math
   --  expr ::= expr '<' expr
   --  expr ::= expr '<=' expr
   --  expr ::= expr '>' expr
   --  expr ::= expr '=' expr
   --  expr ::= expr '>=' expr
   procedure Parse_Compare (P      : in out Parser;
                            Result : out ELNode_Access) is
      Left  : ELNode_Access;
      Right : ELNode_Access;
      Token : Token_Type;
   begin
      Parse_Math (P, Left);
      loop
         Peek (P, Token);
         case Token is
            when T_LT =>
               Parse_Math (P, Right);
               Left := Create_Node (EL_LT, Left, Right);

            when T_LE =>
               Parse_Math (P, Right);
               Left := Create_Node (EL_LE, Left, Right);

            when T_GT =>
               Parse_Math (P, Right);
               Left := Create_Node (EL_GT, Left, Right);

            when T_GE =>
               Parse_Math (P, Right);
               Left := Create_Node (EL_GE, Left, Right);

            when others =>
               exit;

         end case;
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_Compare;

   --  Parse a math expression '+' or '-' then Multiply
   --  expr ::= factor '+' expr
   --  expr ::= factor '-' expr
   --  expr ::= factor '&' expr
   procedure Parse_Math (P      : in out Parser;
                         Result : out ELNode_Access) is
      Left  : ELNode_Access;
      Right : ELNode_Access;
      Token : Token_Type;
   begin
      Parse_Multiply (P, Left);
      loop
         Peek (P, Token);
         case Token is
            when T_PLUS =>
               Parse_Multiply (P, Right);
               Left := Create_Node (EL_ADD, Left, Right);

            when T_MINUS =>
               Parse_Multiply (P, Right);
               Left := Create_Node (EL_SUB, Left, Right);

            when T_AND =>
               Parse_Multiply (P, Right);
               Left := Create_Node (EL_AND, Left, Right);

            when others =>
               exit;

         end case;
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_Math;

   --  Parse a multiply '*' '/' '%' then Unary
   --  factor ::= term '*' factor
   --  factor ::= term '/' factor
   --  factor ::= term
   procedure Parse_Multiply (P      : in out Parser;
                             Result : out ELNode_Access) is
      Token : Token_Type;
      Left, Right : ELNode_Access;
   begin
      Parse_Unary (P, Left);
      loop
         Peek (P, Token);
         case Token is
            when T_MUL =>
               Parse_Unary (P, Right);
               Left := Create_Node (EL_MUL, Left, Right);

            when T_Div =>
               Parse_Unary (P, Right);
               Left := Create_Node (EL_DIV, Left, Right);

            when T_MOD =>
               Parse_Unary (P, Right);
               Left := Create_Node (EL_MOD, Left, Right);

            when others =>
               exit;

         end case;
      end loop;
      Put_Back (P, Token);
      Result := Left;
   end Parse_Multiply;

   --  Parse a unary '!' '-' 'not' 'empty' then value
   --  unary ::= '(' choice ')'
   --  unary ::= ! unary
   --  unary ::= not unary
   --  unary ::= '-' unary
   --  term ::= '(' expr ')'
   --  term ::= literal
   --  term ::= ['-'] number ['.' number [{'e' | 'E'} number]]
   --  term ::= name '.' name
   --  number ::= [0-9]+
   --
   procedure Parse_Unary (P      : in out Parser;
                          Result : out ELNode_Access) is
      Token : Token_Type;
      Node  : ELNode_Access;
   begin
      loop
         Peek (P, Token);
         case Token is
            --  Parenthesis expression
            when T_LEFT_PARENT =>
               Parse_Choice (P, Result);
               Peek (P, Token);
               if Token /= T_RIGHT_PARENT then
                  raise Invalid_Expression with "Missing ')' at end of expression";
               end if;
               return;

            when T_NOT =>
               Parse_Unary (P, Node);
               Result := Create_Node (EL_NOT, Node);
               return;

            when T_MINUS =>
               Parse_Unary (P, Node);
               Result := Create_Node (EL_MINUS, Node);
               return;

            when T_EMPTY =>
               Parse_Unary (P, Node);
               Result := Create_Node (EL_MINUS, Node);
               return;

            when T_NUMBER =>
               Result := Create_Node (P.Value);
               return;
               --
            when T_LITERAL =>
               Result := Create_Node (P.Token);
               return;

            when T_TRUE =>
               Result := Create_Node (True);
               return;

            when T_FALSE =>
               Result := Create_Node (False);
               return;

            when T_NULL =>
               Result := Create_Node (False);
               return;

               --              when T_MINUS =>
--                 Peek (P, Token);
--                 if Token = T_NUMBER then
--                    Result := Create_Node (-P.Value);
--                    return;
--                 end if;
--                 raise Invalid_Expression with "Missing number after '-'";

            when T_NAME =>
               --  name
               --  name.name.name
               --  name[expr]
               --  name.name[expr]
               --  name(expr,...,expr)
               --  Result := Create_Node (P.Token);
               declare
                  Name : Unbounded_String := To_Unbounded_String (P.Token);
                  C    : Wide_Wide_Character;
               begin
                  if P.Pos <= P.Last then
                     C := P.Expr (P.Pos);
                  else
                     C := ' ';
                  end if;
                  if C = '.' then
                     Result := Create_Variable (Name);

                     --  Parse one or several property extensions
                     while C = '.' loop
                        P.Pos := P.Pos + 1;
                        Peek (P, Token);
                        exit when Token /= T_NAME;
                        Name := To_Unbounded_String (P.Token);
                        Result := Create_Value (Variable => Result, Name => Name);
                        if P.Pos <= P.Last then
                           C := P.Expr (P.Pos);
                        else
                           C := ' ';
                        end if;
                     end loop;

                     --  Parse a function call
                  elsif C = ':' then
                     P.Pos := P.Pos + 1;
                     Peek (P, Token);
                     if P.Pos <= P.Last then
                        C := P.Expr (P.Pos);
                     else
                        C := ' ';
                     end if;
                     if Token /= T_NAME or C /= '(' then
                        raise Invalid_Expression with "Missing function name after ':'";
                     end if;
                     Parse_Function (P, Name, To_Unbounded_String (P.Token), Result);

                  --  Parse a function call
                  elsif C = '(' then
                     Parse_Function (P, To_Unbounded_String (""), Name, Result);

                  else
                     Result := Create_Variable (Name);
                  end if;
               end;
               return;

            when others =>
               raise Invalid_Expression with "Syntax error in expression";
         end case;
      end loop;
   end Parse_Unary;

   --  Put back a token in the buffer.
   procedure Put_Back (P : in out Parser; Token : in Token_Type) is
   begin
      P.Pending_Token := Token;
   end Put_Back;

   --  Parse the expression buffer to find the next token.
   procedure Peek (P : in out Parser; Token : out Token_Type) is
      C, C1 : Wide_Wide_Character;
   begin
      --  If a token was put back, return it.
      if P.Pending_Token /= T_EOL then
         Token := P.Pending_Token;
         P.Pending_Token := T_EOL;
         return;
      end if;

      --  Skip white spaces
      while P.Pos <= P.Last loop
         C := P.Expr (P.Pos);
         exit when C /= ' ' and C /= ' ';
         P.Pos := P.Pos + 1;
      end loop;

      --  Check for end of string.
      if P.Pos > P.Last then
         Token := T_EOL;
         return;
      end if;

      --  See what we have and continue parsing.
      P.Pos := P.Pos + 1;
      case C is
         --  Literal string using single or double quotes
         --  Collect up to the end of the string and put
         --  the result in the parser token result.
         when ''' | '"' =>
            Set_Unbounded_Wide_Wide_String (P.Token, "");
            while P.Pos <= P.Last loop
               C1 := P.Expr (P.Pos);
               P.Pos := P.Pos + 1;
               if C1 = '\' then
                  C1 := P.Expr (P.Pos);
                  P.Pos := P.Pos + 1;
               elsif C1 = C then
                  Token := T_LITERAL;
                  return;
               end if;
               Append (P.Token, C1);
            end loop;
            raise Invalid_Expression with "Missing ' or """;

         --  Number
         when '0' .. '9' =>

            P.Pos := P.Pos - 1;
            Parse_Number (P, P.Value);
            if P.Pos <= P.Last then
               declare
                  Decimal_Part : Long_Long_Integer := 0;
               begin
                  C := P.Expr (P.Pos);
                  if C = '.' then
                     P.Pos := P.Pos + 1;
                     if P.Pos <= P.Last then
                        C := P.Expr (P.Pos);
                        if C in '0' .. '9' then
                           Parse_Number (P, Decimal_Part);
                        end if;
                     end if;
                  end if;
               end;
            end if;

            Token := T_NUMBER;
            return;

         --  Parse a name composed of letters or digits.
         when 'a' .. 'z' | 'A' .. 'Z' =>
            Set_Unbounded_Wide_Wide_String (P.Token, "");
            Append (P.Token, C);
            while P.Pos <= P.Last loop
               C := P.Expr (P.Pos);
               exit when not (C in 'a' .. 'z' or C in 'A' .. 'Z'
                              or C in '0' .. '9' or C = '_');
               Append (P.Token, C);
               P.Pos := P.Pos + 1;
            end loop;

            --  and empty eq false ge gt le lt ne not null true
            case Element (P.Token, 1) is
               when 'a' | 'A' =>
                  if P.Token = "and" then
                     Token := T_LOGICAL_AND;
                     return;
                  end if;

               when 'd' | 'D' =>
                  if P.Token = "div" then
                     Token := T_Div;
                     return;
                  end if;

               when 'e' | 'E' =>
                  if P.Token = "eq" then
                     Token := T_EQ;
                     return;
                  elsif P.Token = "empty" then
                     Token := T_EMPTY;
                  end if;

               when 'f' | 'F' =>
                  if P.Token = "false" then
                     Token := T_FALSE;
                     return;
                  end if;

               when 'g' | 'G' =>
                  if P.Token = "ge" then
                     Token := T_GE;
                     return;

                  elsif P.Token = "gt" then
                     Token := T_GT;
                     return;
                  end if;

               when 'm' | 'M' =>
                  if P.Token = "mod" then
                     Token := T_MOD;
                     return;
                  end if;

               when 'l' | 'L' =>
                  if P.Token = "le" then
                     Token := T_LE;
                     return;

                  elsif P.Token = "lt" then
                     Token := T_LT;
                     return;
                  end if;

               when 'n' | 'N' =>
                  if P.Token = "not" then
                     Token := T_NOT;
                     return;

                  elsif P.Token = "null" then
                     Token := T_NULL;
                     return;
                  end if;

               when 't' | 'T' =>
                  if P.Token = "true" then
                     Token := T_TRUE;
                     return;
                  end if;

               when others =>
                  null;
            end case;
            Token := T_NAME;
            return;

         when '(' =>
            Token := T_LEFT_PARENT;
            return;

         when ')' =>
            Token := T_RIGHT_PARENT;
            return;

         when '+' =>
            Token := T_PLUS;
            return;

         when '-' =>
            Token := T_MINUS;
            return;

         when '.' =>
            Token := T_DOT;
            return;

         when ',' =>
            Token := T_COMMA;
            return;

         when '*' =>
            Token := T_MUL;
            return;

         when '%' =>
            Token := T_MOD;
            return;

         when '?' =>
            Token := T_QUESTION;
            return;

         when ':' =>
            Token := T_COLON;
            return;

         when '!' =>
            Token := T_NOT;
            return;

         when '<' =>
            --  Comparison operators < or <=
            Token := T_LT;
            if P.Pos <= P.Last then
               C1 := P.Expr (P.Pos);
               if C1 = '=' then
                  P.Pos := P.Pos + 1;
                  Token := T_LE;
               end if;
            end if;
            return;

         when '>' =>
            --  Comparison operators > or >=
            Token := T_GT;
            if P.Pos <= P.Last then
               C1 := P.Expr (P.Pos);
               if C1 = '=' then
                  P.Pos := P.Pos + 1;
                  Token := T_GE;
               end if;
            end if;
            return;

         when '&' =>
            Token := T_AND;
            if P.Pos <= P.Last then
               C1 := P.Expr (P.Pos);
               if C1 = '&' then
                  Token := T_LOGICAL_AND;
                  P.Pos := P.Pos + 1;
               end if;
            end if;
            return;

         when '=' =>
            Token := T_EQ;
            return;

         when others =>
            Token := T_UNKNOWN;
            return;
      end case;
   end Peek;

   --  Parse a number
   procedure Parse_Number (P      : in out Parser;
                           Result : out Long_Long_Integer) is
      Value : Long_Long_Integer := 0;
      Num   : Long_Long_Integer;
      C     : Wide_Wide_Character;
   begin
      while P.Pos <= P.Last loop
         C := P.Expr (P.Pos);
         exit when C not in '0' .. '9';
         Num := Wide_Wide_Character'Pos (C) - Wide_Wide_Character'Pos ('0');
         Value := Value * 10 + Num;
         P.Pos := P.Pos + 1;
      end loop;
      Result := Value;
   end Parse_Number;

   --  ------------------------------
   --  Parse a function call.
   --  The function call can have up to 4 arguments.
   --  ------------------------------
   procedure Parse_Function (P         : in out Parser;
                             Namespace : in Unbounded_String;
                             Name      : in Unbounded_String;
                             Result    : out ELNode_Access) is
      Token : Token_Type;
      Arg1, Arg2, Arg3, Arg4 : ELNode_Access;
      Func : Function_Access;
      NS   : constant String := To_String (Namespace);
      N    : constant String := To_String (Name);
   begin

      if P.Mapper = null then
         raise Invalid_Expression with "There is no function mapper";
      end if;

      Func := P.Mapper.Get_Function (NS, N);
      --  if Func = null then
      --   raise Invalid_Expression with "Function '" & N & "' not found";
      --  end if;

      --  Extract the first argument.
      --  Number of arguments is pre-defined
      P.Pos := P.Pos + 1;
      Parse_Choice (P, Arg1);
      Peek (P, Token);
      if Token /= T_COMMA then
         if Token /= T_RIGHT_PARENT then
            raise Invalid_Expression with "Missing ')' at end of function call";
         end if;
         Result := Create_Node (Func, Arg1);
         return;
      end if;
      Parse_Choice (P, Arg2);
      Peek (P, Token);
      if Token /= T_COMMA then
         if Token /= T_RIGHT_PARENT then
            raise Invalid_Expression with "Missing ')' at end of function call";
         end if;
         Result := Create_Node (Func, Arg1, Arg2);
         return;
      end if;
      Parse_Choice (P, Arg3);
      Peek (P, Token);
      if Token /= T_COMMA then
         if Token /= T_RIGHT_PARENT then
            raise Invalid_Expression with "Missing ')' at end of function call";
         end if;
         Result := Create_Node (Func, Arg1, Arg2, Arg3);
         return;
      end if;
      Parse_Choice (P, Arg4);
      Peek (P, Token);
      Result := Create_Node (Func, Arg1, Arg2, Arg3, Arg4);
      if Token /= T_RIGHT_PARENT then
         raise Invalid_Expression with "Missing ')' at end of function call";
      end if;
   end Parse_Function;

   procedure Parse (Expr    : in String;
                    Context : in ELContext'Class;
                    Result  : out EL.Expressions.Nodes.ELNode_Access) is
      P : Parser;
      S : aliased Wide_Wide_String := To_Wide_Wide_String (Expr);
   begin
      P.Mapper := Context.Get_Function_Mapper;
      P.Expr := S'Unchecked_Access;
      P.Pos := P.Expr.all'First;
      P.Last := P.Expr.all'Last;
      Parse_Choice (P, Result);
      if P.Pos <= P.Last or P.Pending_Token /= T_EOL then
         raise Invalid_Expression with "Syntax error at end of expression";
      end if;
   end Parse;

   procedure Parse (Expr    : in Wide_Wide_String;
                    Context : in ELContext'Class;
                    Result  : out EL.Expressions.Nodes.ELNode_Access) is
      S : aliased Wide_Wide_String := Expr;
      P : Parser;
   begin
      P.Mapper := Context.Get_Function_Mapper;
      P.Expr := S'Unchecked_Access;
      P.Pos := P.Expr.all'First;
      P.Last := P.Expr.all'Last;
      Parse_Choice (P, Result);
      if P.Pos <= P.Last or P.Pending_Token /= T_EOL then
         raise Invalid_Expression with "Syntax error at end of expression";
      end if;
   end Parse;

end EL.Expressions.Parser;
