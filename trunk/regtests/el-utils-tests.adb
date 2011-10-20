-----------------------------------------------------------------------
--  el-contexts-tests - Tests the EL contexts
--  Copyright (C) 2011 Stephane Carrez
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

with Util.Test_Caller;

with Util.Properties;
with Util.Beans.Objects;

with EL.Expressions;
with EL.Contexts.Default;
with EL.Contexts.Properties;
package body EL.Utils.Tests is

   use Util.Tests;
   use Util.Beans.Objects;

   package Caller is new Util.Test_Caller (Test);

   procedure Add_Tests (Suite : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      Caller.Add_Test (Suite, "Test EL.Utils.Expand",
                       Test_Expand_Properties'Access);
      Caller.Add_Test (Suite, "Test EL.Utils.Expand (recursion)",
                       Test_Expand_Recursion'Access);
   end Add_Tests;

   --  ------------------------------
   --  Test expand list of properties
   --  ------------------------------
   procedure Test_Expand_Properties (T : in out Test) is
      Context       : EL.Contexts.Default.Default_Context;
      Props         : Util.Properties.Manager;
      Result        : Util.Properties.Manager;
   begin
      Props.Set ("context", "#{homedir}/context");
      Props.Set ("homedir", "#{home}/#{user}");
      Props.Set ("unknown", "#{not_defined}");
      Props.Set ("user", "joe");
      Props.Set ("home", "/home");
      EL.Utils.Expand (Source  => Props,
                       Into    => Result,
                       Context => Context);

      Assert_Equals (T, "joe", String '(Result.Get ("user")), "Invalid expansion");
      Assert_Equals (T, "/home/joe", String '(Result.Get ("homedir")), "Invalid expansion");
      Assert_Equals (T, "/home/joe/context", String '(Result.Get ("context")),
                     "Invalid expansion");
      Assert_Equals (T, "", String '(Result.Get ("unknown")), "Invalid expansion");
   end Test_Expand_Properties;

   --  ------------------------------
   --  Test expand list of properties
   --  ------------------------------
   procedure Test_Expand_Recursion (T : in out Test) is
      Context       : EL.Contexts.Default.Default_Context;
      Props         : Util.Properties.Manager;
      Result        : Util.Properties.Manager;
   begin
      Props.Set ("context", "#{homedir}/context");
      Props.Set ("homedir", "#{home}/#{user}");
      Props.Set ("user", "joe");
      Props.Set ("home", "#{context}");
      EL.Utils.Expand (Source  => Props,
                       Into    => Result,
                       Context => Context);

      Assert_Equals (T, "joe", String '(Result.Get ("user")), "Invalid expansion");
      Assert_Equals (T, "/joe/context/joe/context/joe/context/joe",
                     String '(Result.Get ("homedir")),
                     "Invalid expansion");
   end Test_Expand_Recursion;

end EL.Utils.Tests;