# Etheracts

Etheracts is a collection of high resolution renders and an arbitrary registration protocol built on Starknet. To participate, you must own a piece from the collection.

## Quick Links

- [Protocol Overview](#ethrx)
- [Collection Overview](#etheracts-collection)
- [Dapp Site](https://etheracts.novemberfork.io)

## Ethrx

The Etheracts contract is deployed on Starknet [here]().

### How It Works

Each $ETHRX token can store arbitrary data on-chain for anyone to view. Only the owner of the token can modify its data and it is wiped upon standard transfers/sales. The data is stored as key-value pairs inside of a mapping, allowing the token to be used for a wide range of things; including but not limited to: an address routing service, an on-chain profile page/business card/billboard, an exclusive messaging board, etc. etc.


### Engravings

When an $ETHRX owner sets data in their token, it is referred to as &#34; engraving&#34; the token. An engraving has two components: the tag and the content, and each token is capable of storing any number of engravings. A tag is stored as a felt252, and the content is stored as bytes. This means tags can be at most 31 (ASCII) characters long, and the content can be as long as the user wants (gas fees are proportional to content length).

Any arbitrary tag can be engraved into a token, and all historical records are kept on-chain. A full contract indexer will be released for more in-depth/historical data retrieval in the future. Until then, only **official** tags are displayed by default, all other tags will need to be manually searched. Over time, as the protocol matures, more tags will become official and be displayed by default. If a tag is not displayed by default and you think it should be, create an issue in this repo.

### Un/Official Tags

Until the contract indexer is live, there is an on-chain list of "official" tags that are supported by the visualizer. At the current time, these tags are: `TITLE`, `X_HANDLE`, `GITHUB_HANDLE`, `URL`, and `MESSAGE`.

The only purpose of this official tag list is to allow for basic batch retrieval of engravings using simple RPC calls. Once the indexer and backend are live, we will be able to easily display all tags for a token regardless of whether they are official or not (as well as see the history of each too). Meaning the official tag list is only necessary while there is no indexer; once the indexer is live, the official tag list becomes irrelevant.

#### Example

Matt engraves his token with the following data:
- **'X_HANDLE'**: **"degendeveloper"**
- **'GITHUB_HANDLE'**: **"0xDegenDeveloper"**
- **'MESSAGE'**: **"very important message that I want everyone to see that no one can control except me"**
- **'ETH_ADDRESS'**: **"0xD5150c9e61ADbcA91A0F6908d5f7A5440E7E96E5"**
- **'FAVORITE_COLOR'**: **"GREEEN"**

In this example, Matt has left 5 engravings, 3 were for official tags and 2 were not. By default, the visualizer will display (and route as necessary) his `X_HANDLE`, `GITHUB_HANDLE`, and `MESSAGE`, but not his `ETH_ADDRESS` or `FAVORITE_COLOR`; however, all values can still be manually fetched using the visualizer (or by querying the contract).

After some time, `ETH_ADDRESS` becomes a popular tag and starts to be integrated into other on-chain/web3 services. Once this happens, NovemberFork will add it to the official tag list so that it is displayed by default in the visualizer. Once the indexer is live, this will no longer be necessary because all tags will be displayed (official vs. unofficial become irrelevant).

### More Details

A tag can be re-engraved any number of times by the token owner to update its content. All historical records are stored and retrievable on-chain.

On typical transfers & sales that use `transfer()` or `transfer_from()`, engravings are wiped. There is a special `transfer_and_save_artifact()` function available in the contract to allow a token to be transferred without wiping its engravings. When engravings are wiped, the data is still preserved on-chain.

Here is a high-level overview of how engravings are stored: 

Each token ID is mapped or re-mapped to a unique (sequential) artifact ID when it is minted or wiped. This means when token 1 is minted, it will be mapped to artifact ID 1. If token 2 is minted soon after, it will be mapped to artifact ID 2. If token 1 is sold (wiped) before token 3 is minted, it will be re-mapped to artifact ID 3. When token 3 is minted, it will get mapped to artifact ID 4.

Each artifact ID uses nonces to track updates to tags. This allows for easy updating when tokens are wiped (not requiring overwriting multiple storage slots and allowing historical lookup). For example, Alice mints token 1 (it is mapped to artifact ID 1), by default each tag nonce for an artifact ID 0; i.e,

```rust
// token ID 1 is mapped to artifact ID 1
token_id_to_artifact_id[1] = 1 
// artifact ID 1's tag nonce for 'X_HANDLE' defaults to 0
tag_nonces[1]['X_HANDLE'] = 0 
// 'X_HANDLE' for artifact ID 1 at nonce 0 is empty/blank
engravings[1]['X_HANDLE'][0] = ""
```

Alice engraves an X_HANDLE, this increments the tag's nonce for this artifact ID and adds the content to storage; i.e,

```rust
// artifact ID 1's tag once for 'X_HANDLE' is incremented by 1
tag_nonces[1]['X_HANDLE'] = 1 
// 'X_HANDLE' for artifact ID 1 at nonce 1 is "AlxceInWxndxrlxnd"
engravings[1]['X_HANDLE'][1] = "AlxceInWxndxrlxnd" 
```

Alice re-engraves this tag because she made a typo, this increments the tag&#39;s nonce of the artifact ID and places the content in the new slot; i.e,

```rust 
// artifact ID 1's tag once for 'X_HANDLE' is incremented by 1
tag_nonces[1]['X_HANDLE'] = 2 
// 'X_HANDLE' for artifact ID 1 at nonce 2 is "AliceInWonderland"
engravings[1]['X_HANDLE'][2] = "AliceInWonderland" 
```
Alice is about to be evicted because she longed $ARB as the L2 killer instead of $STRK, so she sells her Etheract on the secondary market to Bob (for a decent chunk of change because the project became quite successful 😉). This updates the artifact ID of the token to the next available artifact ID, which effectively wipes all previous engravings; i.e,

```rust
// token ID 1 is re-mapped to artifact ID 1234
token_id_to_artifact_id[1] = 1234 
// artifact ID 1234's tag nonce for 'X_HANDLE' defaults to 0
tag_nonces[1234]['X_HANDLE'] = 0 
// 'X_HANDLE' for artifact ID 1234 at nonce 0 is empty/blank
engravings[1234]['X_HANDLE'][0] = "" 
```

Bob engraves his token to his desire, but realizes he screwed up and used a potentially compromised wallet to purchase his token. Since Bob has a relatively high IQ (besides his other fuck up), he sets up a Braavos wallet to secure his stuff with biometrics. Once his new wallet is set up, he uses the special `transfer_and_save_artifact()` function to transfer the token without wiping it. This keeps all values in the above mappings the same but transfers ownership of the token to his new wallet.

## Etheracts Collection

The original algorithm for the art was written in September 2021 in a college dorm, and the renderings were generated a couple months later. The content has been held in a hard-drive since. I know I know, {`I'm`} late. The original plan was to release this collection in November of 2021, but right at that time I graduated University, was slapped with a fat stack of student loans, and had to focus on gigs that paid the bills.

### Generation Process
The Etheracts collection was generated using a custom algorithm in p5.js (a fair bit of acid may or may not have been involved in its conception). The algorithm was designed to be configurable using a variety of traits, and after some exploration and debugging, traits were randomized and fed into the machines. The collection has a total of 1,111 pieces; the first 11 had their parameters customized by myself, 1 special one (somewhere between 12-1111) was created manually using an interactive version of the algorithm, and the rest were randomized. The original renders are 4,000px by 4,000 px and took ~13 hours to generate using a bunch of machines in parallel (shoutout UVA for letting me borrow a computer lab for a weekend).

At the current time, the content fetched by the visualizer is 2160px by 2160px. The full-resolution content will be available for download and hosted on IPFS once the collection fully mints.


### "Tokenomics"
Tokens 1-11 were hand curated by myself and are not part of the randomized set. I plan on holding a few of these pieces for forever, giving away a few to family, and maybe auctioning off some of the others. There is a 12th piece in the collection (somewhere between 12 and 1,111) that I created manually using an interactive version of the algorithm. Whoever mints it first gets it, but I will try to buy this token back (assuming its not priced ridiculously). The rest of the pieces were randomized. Tokens 12-111 will be reserved for giveaways/promos/marketing/etc.

If you don't want to do the math that's:

- 1 token that was rendered using an interactive version of the algorithm
- 11 tokens that had their traits customized by myself before being rendered
- 1099 tokens that had their traits randomized within set bounds

I get it, chat GPT servers are down so I'll do this math for you too:

- 111 tokens are not for sale to the public (tokens 1-11 are going to myself, and 12-111 are reserved for giveaways)
- 1,000 tokens are for sale to the public (tokens 112-1,111)

### Statistics Breakdown
Etheracts is an on-chain protocol and visually appealing collection that I created for myself to look at; I do not believe in typical NFT distributions, rarity scales, or other meaningless bits that correspond to a monkey wearing glasses or not. This means pieces were randomized using statistics that I found visually appealing, not ones that would create artificial scarcity. Provided below is a full breakdown of the traits for the curious, and if the market wants to assign value based on it, so be it, but that was not the intention.

```rust
Clusters:

 - 1: 233 (21.0%)
 - 2: 249 (22.4%)
 - 3: 212 (19.1%)
 - 4: 235 (21.2%)
 - 5: 182 (16.4%)

> Total: 1111

Node Size:

- none: 568 (51.1%) <br />
- small: 126 (11.3%) <br />
- medium: 140 (12.6%) <br />
- large: 134 (12.1%) <br />
- xlarge: 142 (12.8%) <br />
- random: 1 (0.1%)

> Total: 1111

Path:

- polar: 448 (40.3%)
- spiral: 444 (40.0%)
- linear: 115 (10.4%) 
- still: 103 (9.3%) 
- custom: 1 (0.1%) 

> Total: 1111

Path Periods:

- 3: 86 (7.7%) 
- 4: 111 (10.0%) 
- 5: 132 (11.9%) 
- 6: 160 (14.4%) 
- 7: 130 (11.7%) 
- 8: 136 (12.2%) 
- 9: 136 (12.2%) 
- 10: 124 (11.2%) 
- 11: 89 (8.0%) 
- 33: 1 (0.1%) 
- 111: 3 (0.3%) 
- 555: 1 (0.1%) 
- 1111: 2 (0.2%) 

> Total: 1111

Polarity:

- (+): 552 (49.7%)
- (-): 558 (50.2%)
- (+/-): 1 (0.1%)

> Total: 1111

Trail:

- true: 870 (78.3%) 
- false: 240 (21.6%) 
- yes and no: 1 (0.1%) 

> Total: 1111

Wavelength:

- constant: 445 (40.1%)
- random: 235 (21.2%) 
- prism: 221 (19.9%)
- split: 210 (18.9%)

> Total: 1111

Nodes:

- 1-10: 291 (26.2%) <br />
- 11-20: 526 (47.3%) <br />
- 21-30: 292 (26.3%) <br />
- 31-40: 1 (0.1%) <br />- {">"}100: 1 (0.1%) <br />

> Total: 1111
```  

### Behind the Scenes

After some back and forth with UVA to get ffmpeg and other dependencies installed on their machines, I was allowed to take over half of a computer lab for a weekend.

During this time my brother had just dropped out of college and was crashing on my couch, so instead of charging him rent, I made him tag along for the rendering process.

Rendering took ~13 hours using the setup below.

https://github.com/user-attachments/assets/ef153836-714f-45c5-b12f-e62b7c0cfb4a

Each log you see in the terminal is a single frame being generated and stitched into an mp4. The original renderings are each 4,000 x 4,000 pixels and take up a little over 100 gbs in total.

https://github.com/user-attachments/assets/88f9d4ee-a7f7-4d37-8917-ca2c48f147d6
