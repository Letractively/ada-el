-----------------------------------------------------------------------
--  el-utils -- Utilities around EL
--  Copyright (C) 2011, 2012 Stephane Carrez
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

with Ada.Strings.Unbounded;

with Util.Strings;
with Util.Beans.Basic;
with Util.Log.Loggers;

with EL.Objects;
with EL.Expressions;
with EL.Contexts.Default;
with EL.Contexts.Properties;
package body EL.Utils is

   use Util.Log;
   use Ada.Strings.Unbounded;
   use Util.Beans.Objects;

   --  The logger
   Log : constant Loggers.Logger := Loggers.Create ("EL.Utils");

   --  ------------------------------
   --  Expand the properties stored in <b>Source</b> by evaluating the EL expressions
   --  used in the property values.  The EL context passed in <b>Context</b> can be used
   --  to specify the EL functions or some pre-defined beans that could be used.
   --  The EL context will integrate the source properties as well as properties stored
   --  in <b>Into</b> (only the <b>Source</b> properties will be evaluated).
   --  ------------------------------
   procedure Expand (Source  : in Util.Properties.Manager'Class;
                     Into    : in out Util.Properties.Manager'Class;
                     Context : in EL.Contexts.ELContext'Class) is

      function Expand (Value   : in String;
                       Context : in EL.Contexts.ELContext'Class) return EL.Objects.Object;

      --  Copy the property identified by <b>Name</b> into the application config properties.
      --  The value passed in <b>Item</b> is expanded if it contains an EL expression.
      procedure Process (Name, Item : in Util.Properties.Value);

      type Local_Resolver is new EL.Contexts.Properties.Property_Resolver with null record;

      --  Get the value associated with a base object and a given property.
      overriding
      function Get_Value (Resolver : in Local_Resolver;
                          Context  : in EL.Contexts.ELContext'Class;
                          Base     : access Util.Beans.Basic.Readonly_Bean'Class;
                          Name     : in Unbounded_String) return EL.Objects.Object;

      --  ------------------------------
      --  Get the value associated with a base object and a given property.
      --  ------------------------------
      overriding
      function Get_Value (Resolver : in Local_Resolver;
                          Context  : in EL.Contexts.ELContext'Class;
                          Base     : access Util.Beans.Basic.Readonly_Bean'Class;
                          Name     : in Unbounded_String) return EL.Objects.Object is
         pragma Unreferenced (Resolver);
      begin
         if Base /= null then
            return Base.Get_Value (To_String (Name));

         elsif Into.Exists (Name) then
            return Util.Beans.Objects.To_Object (String '(Into.Get (Name)));

         elsif Source.Exists (Name) then
            declare
               Value  : constant String := Source.Get (Name);
            begin
               if Util.Strings.Index (Value, '{') = 0 or Util.Strings.Index (Value, '}') = 0 then
                  return Util.Beans.Objects.To_Object (Value);
               end if;

               return Expand (Value, Context);
            end;

         else
            return Util.Beans.Objects.Null_Object;
         end if;
      end Get_Value;

      Recursion : Natural := 10;

      --  ------------------------------
      --  Expand (recursively) the EL expression defined in <b>Value</b> by using
      --  the context.  The recursion is provided by the above context resolver which
      --  invokes <b>Expand</b> if it detects that a value is a possible EL expression.
      --  ------------------------------
      function Expand (Value   : in String;
                       Context : in EL.Contexts.ELContext'Class) return EL.Objects.Object is
         Expr   : EL.Expressions.Expression;
         Result : Util.Beans.Objects.Object;
      begin
         if Recursion = 0 then
            Log.Error ("Too many level of recursion when evaluating expression: {0}", Value);
            return Util.Beans.Objects.Null_Object;
         end if;

         Recursion := Recursion - 1;
         Expr := EL.Expressions.Create_Expression (Value, Context);
         Result := Expr.Get_Value (Context);
         Recursion := Recursion + 1;
         return Result;

         --  Ignore any exception and copy the value verbatim.
      exception
         when others =>
            Recursion := Recursion + 1;
            return Util.Beans.Objects.To_Object (Value);
      end Expand;

      Resolver       : aliased Local_Resolver;
      Local_Context  : aliased EL.Contexts.Default.Default_Context;

      --  ------------------------------
      --  Copy the property identified by <b>Name</b> into the application config properties.
      --  The value passed in <b>Item</b> is expanded if it contains an EL expression.
      --  ------------------------------
      procedure Process (Name, Item : in Util.Properties.Value) is
         use Ada.Strings;
      begin
         if Unbounded.Index (Item, "{") = 0 or Unbounded.Index (Item, "{") = 0 then
            Log.Debug ("Adding config {0} = {1}", Name, Item);

            Into.Set (Name, Item);
         else
            declare
               Value : constant Object := Expand (To_String (Item), Local_Context);
               Val   : Unbounded_String;
            begin
               if not Util.Beans.Objects.Is_Null (Value) then
                  Val := Util.Beans.Objects.To_Unbounded_String (Value);
               end if;
               Log.Debug ("Adding config {0} = {1}", Name, Val);
               Into.Set (Name, Val);
            end;
         end if;
      end Process;

   begin
      Resolver.Set_Properties (Source);
      Local_Context.Set_Function_Mapper (Context.Get_Function_Mapper);
      Local_Context.Set_Resolver (Resolver'Unchecked_Access);

      Source.Iterate (Process'Access);
   end Expand;

   --  ------------------------------
   --  Evaluate the possible EL expressions used in <b>Value</b> and return the
   --  string that correspond to that evaluation.
   --  ------------------------------
   function Eval (Value   : in String;
                  Context : in EL.Contexts.ELContext'Class) return String is
      Expr   : EL.Expressions.Expression;
      Result : Util.Beans.Objects.Object;
   begin
      Expr := EL.Expressions.Create_Expression (Value, Context);
      Result := Expr.Get_Value (Context);
      return Util.Beans.Objects.To_String (Result);

      --  Ignore any exception and copy the value verbatim.
   exception
      when others =>
         return Value;
   end Eval;

   --  ------------------------------
   --  Evaluate the possible EL expressions used in <b>Value</b> and return an
   --  object that correspond to that evaluation.
   --  ------------------------------
   function Eval (Value   : in String;
                  Context : in EL.Contexts.ELContext'Class) return Util.Beans.Objects.Object is
      Expr   : EL.Expressions.Expression;
   begin
      Expr := EL.Expressions.Create_Expression (Value, Context);
      return Expr.Get_Value (Context);

      --  Ignore any exception and copy the value verbatim.
   exception
      when others =>
         return Util.Beans.Objects.To_Object (Value);
   end Eval;

   --  ------------------------------
   --  Evaluate the possible EL expressions used in <b>Value</b> and return an
   --  object that correspond to that evaluation.
   --  ------------------------------
   function Eval (Value   : in Util.Beans.Objects.Object;
                  Context : in EL.Contexts.ELContext'Class) return Util.Beans.Objects.Object is
   begin
      case Util.Beans.Objects.Get_Type (Value) is
         when Util.Beans.Objects.TYPE_STRING | Util.Beans.Objects.TYPE_WIDE_STRING =>
            declare
               S    : constant String := Util.Beans.Objects.To_String (Value);
               Expr : EL.Expressions.Expression;
            begin
               Expr := EL.Expressions.Create_Expression (S, Context);
               return Expr.Get_Value (Context);
            end;

         when others =>
            return Value;
      end case;

      --  Ignore any exception and copy the value verbatim.
   exception
      when others =>
         return Value;
   end Eval;

end EL.Utils;
