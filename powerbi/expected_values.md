# Expected values (reconcile your Power BI report against these)

All values come from the SQL layer (`sql/04_business_analysis.sql`) on `data/sales.db`. With **no filters applied**, the Power BI cards must match exactly (± rounding). Currency is shown as £ (UK retailer; the source file does not state a currency).

## Card visuals (no slicers)

| Measure | Expected |
|---|---|
| Gross Revenue | £10,001,168 |
| Returns Value | £230,248 |
| Net Revenue | £9,770,920 |
| Return Rate % | 2.30% |
| Orders | 19,771 |
| Units Sold | 5,406,070 |
| Active Customers (registered) | 4,333 |
| Avg Order Value | £505.85 |
| Units per Order | 273.4 |

## Monthly net revenue and orders

| Month | Net revenue | Orders | MoM % |
|---|---:|---:|---:|
| 2010-12 | £758,024 | 1,550 | n/a |
| 2011-01 | £578,837 | 1,080 | -23.6% |
| 2011-02 | £499,448 | 1,093 | -13.7% |
| 2011-03 | £679,204 | 1,440 | +36.0% |
| 2011-04 | £482,039 | 1,235 | -29.0% |
| 2011-05 | £730,966 | 1,668 | +51.6% |
| 2011-06 | £723,845 | 1,525 | -1.0% |
| 2011-07 | £676,738 | 1,452 | -6.5% |
| 2011-08 | £701,270 | 1,339 | +3.6% |
| 2011-09 | £1,011,333 | 1,818 | +44.2% |
| 2011-10 | £1,061,698 | 2,005 | +5.0% |
| 2011-11 | £1,427,121 | 2,751 | +34.4% |
| 2011-12 (partial) | £440,396 | 815 | n/a |

## Net revenue by region

| Region | Net revenue |
|---|---:|
| United Kingdom | £8,280,992 |
| Europe (ex-UK) | £1,274,859 |
| Asia-Pacific | £191,196 |
| Middle East | £12,140 |
| Americas & Africa | £6,992 |
| Unspecified | £4,741 |

## Net revenue by product group

| Product group | Net revenue | % of total | Return rate |
|---|---:|---:|---:|
| Home Decor | £2,721,416 | 27.9% | 1.96% |
| Kitchen & Dining | £2,244,357 | 23.0% | 3.35% |
| Other | £1,202,406 | 12.3% | 1.73% |
| Bags & Accessories | £1,138,328 | 11.7% | 1.69% |
| Lighting & Candles | £807,136 | 8.3% | 3.17% |
| Party & Gifting | £591,179 | 6.1% | 0.96% |
| Christmas & Seasonal | £498,276 | 5.1% | 2.05% |
| Stationery & Crafts | £290,644 | 3.0% | 2.48% |
| Toys & Games | £223,970 | 2.3% | 2.65% |
| Jewellery | £53,209 | 0.5% | 1.95% |
