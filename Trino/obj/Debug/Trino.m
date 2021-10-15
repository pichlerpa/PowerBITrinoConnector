﻿///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
/////////////                                                                 /////////////
/////////////    Title: Trino Connector for Power BI                         ///////////// 
/////////////    Created by: Patrick Pichler (pichlerpatr@gmail.com)          ///////////// 
/////////////    Website: https://github.com/pichlerpa/ConnectorTrinoPowerBI  ///////////// 
/////////////                                                                 ///////////// 
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////

section Trino;

[DataSource.Kind="Trino", Publish="Trino.Publish"]
 shared Trino.Contents = Value.ReplaceType(TrinoImpl, TrinoType);

TrinoType = type function (
    Host as (type text meta [
        //DataSource.Path = true,
        Documentation.FieldCaption = "Host",
        Documentation.FieldDescription = "The host name of the Trino coordinator.",
        Documentation.SampleValues = {"trinohost"}
    ]),
    Port as (type number meta [
        //DataSource.Path = true,
        Documentation.FieldCaption = "Port",
        Documentation.FieldDescription = "The port to connect the Trino coordinator. Default: http=8080, https=8443",
        Documentation.SampleValues = {8080}
    ]),
    optional Catalog as (type text meta [
        //DataSource.Path = true,
        Documentation.FieldCaption = "Catalog",
        Documentation.FieldDescription = "The catalog name to run queries against.",
        Documentation.SampleValues = {"Hive"}
    ])
    )
    as table meta [
        Documentation.Name = "Trino",
        Documentation.LongDescription = "Trino Client REST API"        
    ];

User = "Trino";
Duration = #duration(0,0,0,0);
Http = if (Extension.CurrentCredential()[AuthenticationKind]?) = "UsernamePassword" then "https://" else "http://";

TrinoImpl = (Host as text, Port as number, optional Catalog as text) as table =>
    let
        Url = Http & Host & ":" & Number.ToText(Port) & "/v1/statement",
        Table = TrinoNavTable(Url, Catalog)
        //test = Json.Document(TrinoType)
    in
        Table;

PostStatementCatalogs = (url as text, optional Catalog as text) as table =>    
    Table.Buffer(let
        response = Value.WaitFor(
                (iteration) =>
                    let
                        isRetry = if iteration > 0 then true else false,
                        responsePrepare = () => Web.Contents(url, 
                            [
                                Content=Text.ToBinary("show catalogs")
                                //,Headers = [#"X-Trino-User" = User]
                                ,IsRetry = isRetry
                            ]
                        ),
                        response = Function.InvokeAfter(responsePrepare, Duration),
                        buffered = Binary.Buffer(response),
                        responseCode = Value.Metadata(response)[Response.Status],
                        actualResult = if buffered <> null and responseCode = 200 then buffered else null
                    in
                        actualResult,
                (iteration) => Duration,
                5),
        body = Json.Document(response),
        Source = if (Record.HasFields(body, {"error"})) then error body[error][message] else GetAllPagesByNextLink(body[nextUri])        
     in
        if Catalog = null then Source else #table({"Catalog"}, {{Catalog}}));

PostStatementSchemas = (url as text, Catalog as text) as table  =>    
    Table.Buffer(let
         response = Value.WaitFor(
                (iteration) =>
                    let
                        isRetry = if iteration > 0 then true else false,
                        responsePrepare = () => Web.Contents(url, 
                            [
                                Content=Text.ToBinary("select schema_name from " & Catalog & ".information_schema.schemata")
                                //,Headers = [#"X-Trino-User" = User]
                                ,IsRetry = isRetry
                            ]
                        ), 
                        response = Function.InvokeAfter(responsePrepare, Duration),
                        buffered = Binary.Buffer(response),
                        responseCode = Value.Metadata(response)[Response.Status],
                        actualResult = if buffered <> null and responseCode = 200 then buffered else null
                    in
                        actualResult,
                (iteration) => Duration,
                5),
        body = Json.Document(response),
        Source = if (Record.HasFields(body, {"error"})) then error body[error][message] else GetAllPagesByNextLink(body[nextUri])

     in
        Source);

PostStatementTables = (url as text, Catalog as text, Schema as text) as table  =>    
    let
        response = Value.WaitFor(
                (iteration) =>
                    let
                        isRetry = if iteration > 0 then true else false,
                        responsePrepare = () => Web.Contents(url, 
                            [
                                Content=Text.ToBinary("select table_name, table_schema from " & Catalog & ".information_schema.tables where table_schema = '" & Schema & "'")
                                //,Headers = [#"X-Trino-User" = User]
                                ,IsRetry = isRetry
                            ]
                        ), 
                        response = Function.InvokeAfter(responsePrepare, Duration),
                        buffered = Binary.Buffer(response),
                        responseCode = Value.Metadata(response)[Response.Status],
                        actualResult = if buffered <> null and responseCode = 200 then buffered else null
                    in
                        actualResult,
                (iteration) => Duration,
                5),
        body = Json.Document(response),
        Source = if (Record.HasFields(body, {"error"})) then error body[error][message] else GetAllPagesByNextLink(body[nextUri])

     in
        Source;


PostStatementQueryTables = (url as text, Catalog as text, schema as text, table as text) as table  =>    
    let
        response = Value.WaitFor(
                (iteration) =>
                    let
                        isRetry = if iteration > 0 then true else false,
                        responsePrepare = () => Web.Contents(url, 
                            [
                                Content=Text.ToBinary("select * from " & Catalog & "." & schema & "." & table)
                                //,Headers = [#"X-Trino-User" = User]
                                ,IsRetry = isRetry
                            ]
                        ), 
                        response = Function.InvokeAfter(responsePrepare, Duration),
                        buffered = Binary.Buffer(response),
                        responseCode = Value.Metadata(response)[Response.Status],
                        actualResult = if buffered <> null and responseCode = 200 then buffered else null
                    in
                        actualResult,
                (iteration) => Duration,
                5),
        body = Json.Document(response),
        Source = if (Record.HasFields(body, {"error"})) then error body[error][message] else GetAllPagesByNextLink(body[nextUri])

     in
        Source;

GetPage = (url as text) as table =>
    let
        response = Value.WaitFor(
                (iteration) =>
                    let
                        isRetry = if iteration > 0 then true else false,
                        responsePrepare = () => Web.Contents(url, 
                            [
                                //Headers = [#"X-Trino-User" = User]
                                IsRetry = isRetry                             
                            ]
                        ), 
                        response = Function.InvokeAfter(responsePrepare, Duration),
                        buffered = Binary.Buffer(response),
                        responseCode = Value.Metadata(response)[Response.Status],
                        actualResult = if buffered <> null and responseCode = 200 then buffered else null
                    in
                        actualResult,
                (iteration) => Duration,
                5),
        body = Json.Document(response),
        nextLink = GetNextLink(body), 

        DataTable =
            if (Record.HasFields(body, {"columns","data"}) and not List.IsEmpty(body[data]) and not List.IsEmpty(body[columns])) then
                let
                         //Prepare column names and appropriate types
                        ColumnTableConvert = Record.ToTable(body),
                        ColumnTableFilteredRows = Table.SelectRows(ColumnTableConvert, each ([Name] = "columns")),
                        ColumnTableExpandedValue = Table.ExpandListColumn(ColumnTableFilteredRows, "Value"),
                        ColumnTableFilteredRowsExpandedValue = Table.ExpandRecordColumn(ColumnTableExpandedValue, "Value", {"name", "type"}, {"name", "type"}),
                        ColumnTable = Table.RemoveColumns(ColumnTableFilteredRowsExpandedValue,{"Name"}),
                        ColumnTableMapping = Table.AddColumn(ColumnTable, "typeMapping", each 
                            if Text.Contains([type], "char") then type text //VARCHAR, CHAR
                            else if Text.Contains([type], "int") then type number //TINYINT, SMALLINT, INTEGER, BIGINT
                            else if Text.Contains([type], "decimal") then type number //DECIMAL
                            else if Text.Contains([type], "boolean") then type logical //BOOLEAN
                            else if Text.Contains([type], "date") then type date //DATE
                            else if Text.Contains([type], "timestamp") then type datetime //TIMESTAMP, TIMESTAMP(P),TIMESTAMP WITH TIME ZONE, TIMESTAMP(P) WITH TIME ZONE
                            else if Text.Contains([type], "time") then type time //TIME, TIME(P), TIME WITH TIME ZONE                            
                            else if Text.Contains([type], "real") then type number //REAL
                            else if Text.Contains([type], "double") then type number //DOUBLE  
                            else if Text.Contains([type], "varbinary") then type binary //VARBINARY
                            else type text), //INTERVAL YEAR TO MONTH, INTERVAL DAY TO SECOND, MAP, JSON, ARRAY, ROW, IPADDRESS, UUID
                        ColumnTableMappingTranspose = Table.Transpose(Table.SelectColumns(ColumnTableMapping,{"name","typeMapping"})),
                        ColumnTableMappingTransposeList = Table.ToColumns(ColumnTableMappingTranspose),

                        //Prepare corresponding data
                        DataTableConvert = Record.ToTable(body),
                        DataTableFilteredRows = Table.SelectRows(DataTableConvert, each ([Name] = "data")),
                        DataTableConvertExpandedValue = Table.ExpandListColumn(DataTableFilteredRows, "Value"),
                        DataTableFilteredRowsAddedCustom = Table.AddColumn(DataTableConvertExpandedValue, "Custom", each Table.Transpose(Table.FromList([Value], Splitter.SplitByNothing(), null, null, ExtraValues.Error))),
                        Data = Table.SelectColumns(DataTableFilteredRowsAddedCustom,{"Custom"}),

                        //Bring together columns and data
                        ColumnTableColumnsList = List.Generate(()=> [Counter=1], each [Counter] <= Table.RowCount(ColumnTable), each [Counter=[Counter]+1], each "Column" & Number.ToText([Counter])),
                        DataTableFilteredRowsExpandedCustom = Table.ExpandTableColumn(Data, "Custom", ColumnTableColumnsList),
                        DataTableReName = Table.RenameColumns(DataTableFilteredRowsExpandedCustom,List.Zip({Table.ColumnNames(DataTableFilteredRowsExpandedCustom),ColumnTable[name]})),
                        DataTableReType = Table.TransformColumnTypes(DataTableReName, ColumnTableMappingTransposeList)                                       
  
                   in
                        DataTableReType 
            else if (Record.HasFields(body, {"error"})) then 
                    let
                        Output = error Error.Record(body[error][errorName], body[error][message], body[error][failureInfo][stack])
                    in
                        Output
            else
                #table({},{})                     
    in
        DataTable meta [NextLink = nextLink];

///////////////////////
///// NAVIGATION //////
///////////////////////

TrinoNavTable = (url as text, optional Catalog as text) as table =>
    let
        catalogs = PostStatementCatalogs(url,Catalog),
        catalogsRename = Table.RenameColumns(catalogs, {Table.ColumnNames(#"catalogs"){0},"Name"}),
        catalogsRenameSort = Table.Sort(catalogsRename, {"Name"}),
        NameKeyColumn = Table.DuplicateColumn(catalogsRenameSort,"Name","NameKey", type text),
        UrlColumn = Table.AddColumn(NameKeyColumn,"Url", each url),
        //DataColumn = Table.AddColumn(UrlColumn ,"Data", each TrinoNavTableLeaf(url,[Name])),
        ItemKindColumn = Table.AddColumn(UrlColumn,"ItemKind", each "Database"),
        ItemNameColumn = Table.AddColumn(ItemKindColumn,"ItemName", each "Database"),
        IsLeafColumn = Table.AddColumn(ItemNameColumn,"IsLeaf", each false),
        source = IsLeafColumn,
        //navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        AsNavigationView = Table.NavigationTableView(() => source, {"Url","NameKey"}, TrinoNavTableLeaf, [
            Name = each [Name],
            ItemKind = each [ItemKind],
            ItemName = each [ItemName],
            IsLeaf = each [IsLeaf]
        ])
    in
        AsNavigationView;

TrinoNavTableLeaf = (url as text, Catalog as text) as table =>
    let        
        schemas = PostStatementSchemas(url,Catalog),
        schemasConc = Table.AddColumn(schemas, "Name", each [schema_name]),
        tablesConcSort = Table.Sort(schemasConc, {"Name"}),        
        NameKeyColumn = Table.DuplicateColumn(tablesConcSort,"Name","NameKey", type text),
        UrlColumn = Table.AddColumn(NameKeyColumn,"Url", each url),
        CatalogColumn = Table.AddColumn(UrlColumn,"Catalog", each Catalog),
        //DataColumn = Table.AddColumn(UrlColumn,"Data", each TrinoNavTableLeafLeaf(url,Catalog,[schema_name])),
        ItemKindColumn = Table.AddColumn(CatalogColumn,"ItemKind", each "Folder"),
        ItemNameColumn = Table.AddColumn(ItemKindColumn,"ItemName", each "Folder"),
        IsLeafColumn = Table.AddColumn(ItemNameColumn,"IsLeaf", each false),
        source = IsLeafColumn,
        //navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        AsNavigationView = Table.NavigationTableView(() => source, {"Url","Catalog","NameKey"}, TrinoNavTableLeafLeaf, [
            Name = each [Name],
            ItemKind = each [ItemKind],
            ItemName = each [ItemName],
            IsLeaf = each [IsLeaf]
        ])
    in
        AsNavigationView;

TrinoNavTableLeafLeaf = (url as text, Catalog as text, Schema as text) as table =>
    let
        tables = PostStatementTables(url,Catalog,Schema),
        tablesConc = Table.AddColumn(tables, "Name", each [table_schema] & "." & [table_name]),
        tablesConcSort = Table.Sort(tablesConc, {"Name"}),   
        NameKeyColumn = Table.DuplicateColumn(tablesConcSort,"Name","NameKey", type text),
        UrlColumn = Table.AddColumn(NameKeyColumn,"Url", each url),
        CatalogColumn = Table.AddColumn(UrlColumn,"Catalog", each Catalog),
        SchemaColumn = Table.AddColumn(CatalogColumn, "Schema", each [table_schema]),
        TableColumn = Table.AddColumn(SchemaColumn, "Table", each [table_name]),
        //DataColumn = Table.AddColumn(tablesConcSort,"Data", each Diagnostics.LogFailure("Error in GetEntity", () => PostStatementQueryTables(url,Catalog,[table_schema],[table_name]))),
        //DataColumn = Table.AddColumn(tablesConcSort,"Data", each PostStatementQueryTables(url,Catalog,[table_schema],[table_name])),
        ItemKindColumn = Table.AddColumn(TableColumn,"ItemKind", each "Table"),
        ItemNameColumn = Table.AddColumn(ItemKindColumn,"ItemName", each "Table"),
        IsLeafColumn = Table.AddColumn(ItemNameColumn,"IsLeaf", each true),        
        source = IsLeafColumn,
        //navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        AsNavigationView = Table.NavigationTableView(() => source, {"Url","Catalog","Schema","Table"},  PostStatementQueryTables, [
             Name = each [Name],
             ItemKind = each [ItemKind],
             ItemName = each [ItemName],
             IsLeaf = each [IsLeaf]
        ])
    in
        AsNavigationView;  


//////////////////////
//// DATA SOURCE /////
//////////////////////

//Data Source Kind description
Trino = [
    Authentication = [
        UsernamePassword = [
            UsernameLabel = Extension.LoadString("UsernameLabelText"),
            PasswordLabel = Extension.LoadString("PasswordLabelText")
        ],   
        Implicit = []
    ],  
   TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            host = json[Host],
            port = json[Port]
        in
            { "Trino.Contents", host, port }
    //TestConnection = (dataSourcePath) => { "Trino.Contents" },
    //Label = "Trino"
];

// Data Source UI publishing description
Trino.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Trino.Icons,
    SourceTypeImage = Trino.Icons
];

Trino.Icons = [
    Icon16 = { Extension.Contents("Trino16.png"), Extension.Contents("Trino20.png"), Extension.Contents("Trino24.png"), Extension.Contents("Trino32.png") },
    Icon32 = { Extension.Contents("Trino32.png"), Extension.Contents("Trino40.png"), Extension.Contents("Trino48.png"), Extension.Contents("Trino64.png") }
]; 

//////////////////////
// HELPER FUNCTIONS //
//////////////////////

// In this implementation, 'response' will be the parsed body of the response after the call to Json.Document.
// Look for the 'nextUri' field and simply return null if it doesn't exist.
GetNextLink = (response) as nullable text => Record.FieldOrDefault(response, "nextUri");

// Read all pages of data.
// After every page, we check the "NextLink" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
GetAllPagesByNextLink = (url as text) as table =>    
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            // if NextLink was set to null by the previous call, we know we have no more data
            page = if (nextLink <> null) then GetPage(nextLink) else null
        in
            page
    );

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;


//The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together and filter out empty pages
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        tableOfPagesFiltered = Table.SelectRows(tableOfPages, each Table.IsEmpty([Column1]) = false),
        firstRow = tableOfPagesFiltered{0}?
    in
        // tableOfPagesFiltered;
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPagesFiltered, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );


// This is intended to be a reusable helper which takes a constructor for the base navigation table,
// a list of key columns whose values uniquely describe a row in the navigation table, a constructor
// for the table to returned as data for a given row in the navigation table, and a record with a
// description of how to construct the output navigation table.
//
// The baseTable constructor will only be invoked if necessary, such as when initially returning the
// navigation table. If a user query is something like "navTable{[Key1=Value1, Key2=Value2]}[Data]",
// then the code will not call the baseTable function and instead just call dataCtor(Value1, Value2).
//
// Obviously, dataCtor itself could return another navigation table.
//
// Disclaimer: this hasn't been as extensively tested as I'd like -- and in fact, I found and fixed a
// bug while setting up the test case above.

Table.NavigationTableView =
(
    baseTable as function,
    keyColumns as list,
    dataCtor as function,
    descriptor as record
) as table =>
    let
        transformDescriptor = (key, value) =>
            let
                map = [
                    Name = "NavigationTable.NameColumn",
                    Data = "NavigationTable.DataColumn",
                    Tags = "NavigationTable.TagsColumn",
                    ItemKind = "NavigationTable.ItemKindColumn",
                    ItemName = "Preview.DelayColumn",
                    IsLeaf = "NavigationTable.IsLeafColumn"
                ]
            in
                if value is list
                    then [Name=value{0}, Ctor=value{1}, MetadataName = Record.FieldOrDefault(map, key)]
                    else [Name=key, Ctor=value, MetadataName = Record.FieldOrDefault(map, key)],
        fields = List.Combine({
            List.Transform(keyColumns, (key) => [Name=key, Ctor=(row) => Record.Field(row, key), MetadataName=null]),
            if Record.HasFields(descriptor, {"Data"}) then {}
                else {transformDescriptor("Data", (row) => Function.Invoke(dataCtor, Record.ToList(Record.SelectFields(row, keyColumns))))},
            Table.TransformRows(Record.ToTable(descriptor), each transformDescriptor([Name], [Value]))
        }),
        metadata = List.Accumulate(fields, [], (m, d) => let n = d[MetadataName] in if n = null then m else Record.AddField(m, n, d[Name])),
        tableKeys = List.Transform(fields, each [Name]),
        tableValues = List.Transform(fields, each [Ctor]),
        tableType = Type.ReplaceTableKeys(
            Value.Type(#table(tableKeys, {})),
            {[Columns=keyColumns, Primary=true]}
        ) meta metadata,
        reduceAnd = (ast) => if ast[Kind] = "Binary" and ast[Operator] = "And" then List.Combine({@reduceAnd(ast[Left]), @reduceAnd(ast[Right])}) else {ast},
        matchFieldAccess = (ast) => if ast[Kind] = "FieldAccess" and ast[Expression] = RowExpression.Row then ast[MemberName] else ...,
        matchConstant = (ast) => if ast[Kind] = "Constant" then ast[Value] else ...,
        matchIndex = (ast) => if ast[Kind] = "Binary" and ast[Operator] = "Equals"
            then
                if ast[Left][Kind] = "FieldAccess"
                    then Record.AddField([], matchFieldAccess(ast[Left]), matchConstant(ast[Right]))
                    else Record.AddField([], matchFieldAccess(ast[Right]), matchConstant(ast[Left]))
            else ...,
        lazyRecord = (recordCtor, keys, baseRecord) =>
            let record = recordCtor() in List.Accumulate(keys, [], (r, f) => Record.AddField(r, f, () => (if Record.FieldOrDefault(baseRecord, f, null) <> null then Record.FieldOrDefault(baseRecord, f, null) else Record.Field(record, f)), true)),
        getIndex = (selector, keys) => Record.SelectFields(Record.Combine(List.Transform(reduceAnd(RowExpression.From(selector)), matchIndex)), keys)
    in
        Table.View(null, [
            GetType = () => tableType,
            GetRows = () => #table(tableType, List.Transform(Table.ToRecords(baseTable()), (row) => List.Transform(tableValues, (ctor) => ctor(row)))),
            OnSelectRows = (selector) =>
                let
                    index = try getIndex(selector, keyColumns) otherwise [],
                    default = Table.SelectRows(GetRows(), selector)
                in
                    if Record.FieldCount(index) <> List.Count(keyColumns) then default
                    else Table.FromRecords({
                        index & lazyRecord(
                            () => Table.First(default),
                            List.Skip(tableKeys, Record.FieldCount(index)),
                            Record.AddField([], "Data", () => Function.Invoke(dataCtor, Record.ToList(index)), true))
                        },
                        tableType)
        ]);


Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);


Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];