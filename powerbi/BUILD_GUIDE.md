# Power BI build guide

> **Important:** a `.pbix` is a binary produced by Power BI Desktop (Windows), so it is not in this repo. Everything needed to build it in ~1-2 hours is here: the cleaned star-schema CSVs (`../exports`), Power Query loaders, DAX measures, theme, page specs and a reconciliation sheet. Once built, **save the `.pbix` into this folder, export screenshots / a PDF, and add them to the README**, because recruiters trust dashboards they can see.

## 1. Load the data
1. Run `python scripts/build_database.py` (or use the CSVs already in `exports/`).
2. Power BI Desktop > **Transform data > Manage parameters > New**: name `DataFolder`, type Text, value = full path to `exports\` **with a trailing backslash**.
3. For each block in [`power_query.m`](power_query.m): **New source > Blank query > Advanced editor**, paste, rename the query (`fact_sales`, `dim_date`, `dim_product`, `dim_customer`, `dim_country`). Close & Apply.

## 2. Model (Model view)
| From (many) | To (one) | Cardinality / filter |
|---|---|---|
| `fact_sales[date_key]` | `dim_date[date_key]` | Many-to-one, single |
| `fact_sales[product_key]` | `dim_product[product_key]` | Many-to-one, single |
| `fact_sales[customer_key]` | `dim_customer[customer_key]` | Many-to-one, single |
| `fact_sales[country]` | `dim_country[country]` | Many-to-one, single |

- Select `dim_date` > **Table tools > Mark as date table** > column `date`.
- **Sort by column:** `dim_date[month_name]` by `month_number`; `dim_date[day_name]` by `day_of_week_number`; `dim_date[quarter]` by `year_quarter_sort`.
- Hide key columns (`*_key`, `sales_key`) from Report view. Set `fact_sales[revenue]`, `unit_price` format to £ and `quantity` to whole number; **do not** use implicit sums, so use the measures.
- Create the measure table and paste everything from [`measures.dax`](measures.dax). Format: revenue measures `£#,0`; `%` measures 0.0%; counts `#,0`.
- View > Themes > **Browse for themes** > [`theme.json`](theme.json).

## 3. Reconcile before designing anything
Add the six cards from [`expected_values.md`](expected_values.md) on a scratch page. If **Net Revenue = £9,770,920** and **Orders = 19,771**, the model is correct. If not, check relationships and the `transaction_type` filters.

## 4. Pages

### Page 1: Executive Overview
| Visual | Fields |
|---|---|
| 6 cards | Net Revenue, Orders, Avg Order Value, Active Customers, Return Rate %, Units per Order |
| Column + line chart | X: `dim_date[year_month]`; columns: Net Revenue; line (secondary): Net Revenue MoM % |
| Bar chart | Y: `dim_product[product_group]`; X: Net Revenue (data labels: % of total) |
| Filled map or bar | `dim_country[country]`, Net Revenue (tooltip: Orders, AOV) |
| Slicers | `dim_date[date]` (between), `dim_country[region]`, `dim_product[product_group]`, `dim_customer[customer_type]` |

Reference render: [`../images/00_dashboard_reference_layout.png`](../images/00_dashboard_reference_layout.png)

### Page 2: Product Performance
- **Top N bar:** `dim_product[description]`, Net Revenue, Top N filter = 15 by Net Revenue.
- **Pareto:** column (Net Revenue) + line ([Pareto Cumulative %]) by `description`, sorted descending, Top N = 100.
- **Matrix:** rows `product_group`, columns `dim_date[quarter]`, values Net Revenue (conditional formatting: colour scale).
- **Table:** description, group, Units Sold, Net Revenue, Return Rate %.
- **Tooltip page:** monthly trend for the hovered product.

### Page 3: Customers & Geography
- **Stacked column:** `year_month`; values New Customers, Returning Customers.
- **Cards:** Returning Customer %, Net Revenue per Customer, Guest Revenue Share %.
- **Bar:** `dim_country[country]` (exclude UK via visual filter) by Net Revenue; second axis/tooltip Avg Order Value.
- **Heat-map matrix:** rows `dim_date[day_name]`, columns `fact_sales[invoice_hour]`, values Orders (colour scale).
- **Top 10 customers table:** `customer_name`, Net Revenue, Orders (Top N filter on Net Revenue; filter `customer_key <> 0`).

### Page 4: Data notes
Text box summarising the cleaning assumptions (see main README: dedup, exclusions, reversed bulk orders, partial December, guest checkouts, heuristic product groups).

## 5. Design checklist
- One message per page; title states the insight where possible ("Q4 drives 2011's growth").
- Consistent theme, aligned grid, sync slicers across pages, hide visual headers if cluttered.
- Mobile layout for page 1 (View > Mobile layout).
- Check performance: all measures are simple `CALCULATE`/`DISTINCTCOUNT`; fact table is ~530K rows (fast in Import mode).

## 6. Publish / show your work
- Save `Sales_Performance_Dashboard.pbix` in this folder (consider Git LFS if it grows).
- File > Export > PDF; screenshot each page at 1920x1080 into `images/` (e.g. `pbi_page1_overview.png`) and embed them at the top of the README.
- Optional: publish to Power BI Service > *Publish to web* is **public**, so only do this with this non-confidential public dataset.
