// =====================================================================
// power_query.m: Power BI Desktop > Get data > Blank query > Advanced editor
// 1) Create a text parameter  DataFolder  e.g.  C:\Users\you\sales-performance-dashboard\exports\
// 2) Create one query per block below (name each query exactly as shown)
// =====================================================================

// ---------------- fact_sales ----------------
let
    Source   = Csv.Document(File.Contents(DataFolder & "fact_sales.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
        {"sales_key", Int64.Type}, {"invoice_no", type text}, {"date_key", Int64.Type},
        {"invoice_hour", Int64.Type}, {"product_key", type text}, {"customer_key", Int64.Type},
        {"country", type text}, {"transaction_type", type text}, {"quantity", Int64.Type},
        {"unit_price", type number}, {"revenue", type number}})
in
    Typed

// ---------------- dim_date ----------------
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_date.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
        {"date_key", Int64.Type}, {"date", type date}, {"year", Int64.Type}, {"month_number", Int64.Type},
        {"month_name", type text}, {"year_month", type text}, {"quarter", type text},
        {"year_quarter_sort", Int64.Type}, {"week_of_year", Int64.Type}, {"day_of_week_number", Int64.Type},
        {"day_name", type text}, {"is_weekend", Int64.Type}, {"is_complete_month", Int64.Type}})
in
    Typed

// ---------------- dim_product ----------------
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_product.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
        {"product_key", type text}, {"description", type text}, {"product_group", type text},
        {"first_sold_date", type date}, {"avg_unit_price", type number}})
in
    Typed

// ---------------- dim_customer ----------------
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_customer.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
        {"customer_key", Int64.Type}, {"customer_name", type text}, {"customer_type", type text},
        {"primary_country", type text}, {"first_order_date", type date}, {"cohort_month", type text},
        {"last_order_date", type date}, {"total_orders", Int64.Type}, {"lifetime_net_revenue", type number}})
in
    Typed

// ---------------- dim_country ----------------
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_country.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {{"country", type text}, {"region", type text}})
in
    Typed
