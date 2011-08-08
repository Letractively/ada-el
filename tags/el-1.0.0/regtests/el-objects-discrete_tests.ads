-----------------------------------------------------------------------
--  el-objects-tests - Generic simple test for discrete object types
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

with AUnit.Test_Suites; use AUnit.Test_Suites;
with AUnit.Test_Fixtures;
with EL.Expressions;
with EL.Objects;

generic
   type Test_Type is private;
   with function To_Type (Obj : EL.OBjects.Object) return Test_Type is <>;
   with function To_Object_Test (V : Test_Type) return EL.Objects.Object is <>;
   with function "-" (Left, Right : Test_Type) return Test_Type is <>;
   with function "+" (Left, Right : Test_Type) return Test_Type is <>;
   with function "=" (Left, Right : Test_Type) return Boolean is <>;
   with function Value (S : String) return Test_Type;
   Test_Name   : String;
   Test_Values : String;
package EL.Objects.Discrete_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      I1 : Integer;
      I2 : Integer;
   end record;

   procedure Add_Tests (Suite : Access_Test_Suite);

end EL.Objects.Discrete_Tests;