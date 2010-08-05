-----------------------------------------------------------------------
--  EL.Variables -- Default Variable Mapper
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
with EL.Expressions;
package body EL.Variables.Default is

   overriding
   procedure Bind (Mapper : in out Default_Variable_Mapper;
                   Name   : in String;
                   Value  : in EL.Objects.Object) is
   begin
      Mapper.Map.Include (Key      => To_Unbounded_String (Name),
                          New_Item => Value);
   end Bind;

   overriding
   function Get_Variable (Mapper : Default_Variable_Mapper;
                          Name   : Unbounded_String)
                          return EL.Expressions.ValueExpression is
      C : constant Variable_Maps.Cursor := Mapper.Map.Find (Name);
   begin
      if not Variable_Maps.Has_Element (C) then
         if Mapper.Next_Mapper /= null then
            return Mapper.Next_Mapper.Get_Variable (Name);
         end if;
         raise No_Variable
           with "Variable not found: '" & To_String (Name) & "'";
      end if;
      return EL.Expressions.Create_ValueExpression (Variable_Maps.Element (C));
   end Get_Variable;

   overriding
   procedure Set_Variable (Mapper : in out Default_Variable_Mapper;
                           Name   : in Unbounded_String;
                           Value  : in EL.Expressions.ValueExpression) is
   begin
      null;
   end Set_Variable;

end EL.Variables.Default;