STEP 1 - Database: run Step1_CreateDatabase.sql (new) or Step1b_AddFaceColumn.sql (if the database already exists).
STEP 2 - Website: edit Server\appsettings.json (sa password). Install .NET 8 SDK on one PC, double-click Server\Publish.bat,
         copy everything inside Server\publish to the IIS site folder. IIS server needs: .NET 8 Hosting Bundle,
         Microsoft Visual C++ Redistributable 2015-2022 (x64), and an application pool set to "No Managed Code".
         Open http://192.168.0.201
STEP 3 - Mobile app (later): MobileApp folder.
