# Feature Matrix

This matrix expands the reference concept into implementation-sized feature
families. It is not a promise that every item belongs in version 1.

| Feature | In-game effect | Real-life basis | Likely phase |
| --- | --- | --- | --- |
| Dynamic land market | NPC farms hold, lease, subdivide, sell, or bid for land based on financial condition. | Farm balance sheets, assets, debt, equity, land values, and business succession. | V2 |
| NPC financial stress events | Stressed farms create urgent harvesting, transport, baling, fertilising, spraying, or silage work. | Input costs often arrive before harvest income, creating cash-flow pressure. | V1.1 |
| Local commodity pressure | Oversupply or crop failure shifts local report pressure and later price/opportunity pressure. | Commodity forecasts track production, demand, supply, and risk. | V1.1 to V2 |
| Realistic NPC crop choice | NPCs rotate toward better expected margins while conservative farms stay familiar. | Farm performance varies by region, industry, farm size, and production cost. | V2 |
| Loans and interest pressure | High debt drives delayed fieldwork, forced sales, urgent work, or conservative choices. | Farm debt and operating finance affect both land and operating decisions. | V2 |
| Insurance and disaster relief | Drought, flood, disease, hail, or market collapse can trigger payouts or government support. | Real farm support programs respond to natural disasters and price or revenue drops. | V3 |
| Co-op mechanics | NPCs and the player join local co-ops for storage, shared machinery, discounts, better sale prices, or dividends. | Agricultural co-ops reduce costs, increase bargaining power, and manage logistics. | V3 |
| Production-chain economy | Local production sites affect demand for crops, feed, substrates, biomass, hauling, and storage. | Real farms sell into regional processors and logistics networks. | V3 |
| Neighbour reputation | Helping distressed farms improves relationships; aggressive bidding can damage them. | Rural communities mix market competition with cooperation. | V2 |
| Farm succession and consolidation | Older NPCs retire, heirs sell land, large farms consolidate, and small farms specialize. | Ownership changes are a major source of long-term land movement. | V3 |
| Bankruptcy and auctions | Farms unable to service debt lose equipment or fields; players can buy assets at reputational cost. | Solvency depends on debt, assets, income, and resilience. | V2 to V3 |
| Government policy scenarios | Grants, conservation payments, fertiliser restrictions, tax rebates, disaster aid, or fuel changes alter incentives. | Public policy shapes farm income, risk, and crop choice. | V3 |
| Regional economy presets | US Midwest, Australian broadacre, EU mixed farming, Alpine dairy, and rice regions get different risks. | Regional datasets support different cost structures and outlooks. | V3 |

## Early-Value Ranking

The strongest first features are:

1. Shadow ledgers that create farm stress and farm confidence.
2. Contextual contract and neighbour-request text.
3. A small local market board.
4. Land pressure indicators before direct land-market mutation.
5. Save-safe event history and cooldowns.

This order gives the player a living economy quickly while avoiding high-risk
FS25 API hooks until they are researched.
