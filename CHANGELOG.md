# [2.0.0-beta.11](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.10...v2.0.0-beta.11) (2026-03-11)


### Bug Fixes

* **checkout:** allow borrower change from confirmation state ([1c58bf7](https://github.com/bonanzahq/bonanza/commit/1c58bf773fb2abc0eb7df9e74d2065903f9a6fb3))
* **checkout:** handle borrower update failure in select_borrower ([34c9674](https://github.com/bonanzahq/bonanza/commit/34c9674b7cfe1109b47b1d5f8022828b7b9617d4))

# [2.0.0-beta.10](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.9...v2.0.0-beta.10) (2026-03-10)


### Bug Fixes

* handle Turbo cache restoration in autocomplete controller ([ca6a163](https://github.com/bonanzahq/bonanza/commit/ca6a1637ed910535575614a1daaa3284cda0b26c)), closes [#216](https://github.com/bonanzahq/bonanza/issues/216)

# [2.0.0-beta.9](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.8...v2.0.0-beta.9) (2026-03-09)


### Bug Fixes

* **borrowers:** merge duplicated includes hash keys ([f83bb4c](https://github.com/bonanzahq/bonanza/commit/f83bb4cf512c171df44fff22d1280b68b3273c93))
* **config:** disable active storage variant processor ([9b5c1e2](https://github.com/bonanzahq/bonanza/commit/9b5c1e23e29abd1802d55d7943d0b0c55d3959c6))

# [2.0.0-beta.8](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.7...v2.0.0-beta.8) (2026-03-09)


### Bug Fixes

* **mailer:** handle nil user in ban notification email ([31d603e](https://github.com/bonanzahq/bonanza/commit/31d603e4858e6c5d0a6cc9b00671d6dbe3da9015))
* **views:** guard against nil user references ([275b302](https://github.com/bonanzahq/bonanza/commit/275b30266f4eefb017b15705c07e8b950d0d1671))


### Features

* **helpers:** add user_display_name for nil-safe user display ([632a9ea](https://github.com/bonanzahq/bonanza/commit/632a9ea370ee68c61a4a11bfb3fe1852904e7f0c))

# [2.0.0-beta.7](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.6...v2.0.0-beta.7) (2026-03-09)


### Bug Fixes

* remove ERB code inside HTML comments ([4bd317b](https://github.com/bonanzahq/bonanza/commit/4bd317be775083750ad865ddcd82d76716f86350)), closes [#215](https://github.com/bonanzahq/bonanza/issues/215)

# [2.0.0-beta.6](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.5...v2.0.0-beta.6) (2026-03-04)


### Bug Fixes

* allow ALLOW_ANONYMIZE to be set via .env file ([96f7e95](https://github.com/bonanzahq/bonanza/commit/96f7e951015aba78ee5fd1c8d4d4a87bfbea183d))
* auto-create missing LegalText records on edit page ([a5b0025](https://github.com/bonanzahq/bonanza/commit/a5b00251d28db07f4677231f3b4ab75a66fbb8e2))
* stop deploy script from overwriting itself ([6e0b235](https://github.com/bonanzahq/bonanza/commit/6e0b23504640d727245307d2779b1cebdcb97918))


### Features

* add help, argument validation, and branch check to deploy script ([a48779c](https://github.com/bonanzahq/bonanza/commit/a48779cb5d3e3e504c52dde6317e58746976f1ab))
* add token validation to deploy script ([4823e8a](https://github.com/bonanzahq/bonanza/commit/4823e8ae72319b6a5304145c893301f9acef9464))
* allow deploy.sh to pull from a specific branch ([936f701](https://github.com/bonanzahq/bonanza/commit/936f701ea0605746129a6cff81544ed76352be68))


### Performance Improvements

* skip Elasticsearch reindex on production startup ([8f03b41](https://github.com/bonanzahq/bonanza/commit/8f03b419064ba380dbb381cd085646c3c93941a2))

# [2.0.0-beta.5](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.4...v2.0.0-beta.5) (2026-03-04)


### Bug Fixes

* **elasticsearch:** construct URL from ES_HOST/ES_PORT/ES_PASSWORD when ELASTICSEARCH_URL unset ([df27392](https://github.com/bonanzahq/bonanza/commit/df2739253605407621dc8859f282c4a81f836f05))
* **elasticsearch:** pass credentials separately to avoid double-encoding ([5a1b601](https://github.com/bonanzahq/bonanza/commit/5a1b601ff255a88bd4dbaee3c827e3dbc1af86d4))
* **elasticsearch:** use RFC 3986 encoding for ES password ([860a25c](https://github.com/bonanzahq/bonanza/commit/860a25c4926436f0fe63800847f0a4cff445262b))
* **migration:** add migration net department for orphaned records ([36278fc](https://github.com/bonanzahq/bonanza/commit/36278fcd3afe3d72da9014bd91f850efaaf8bde9))
* **migration:** address PR review feedback ([d2d45a0](https://github.com/bonanzahq/bonanza/commit/d2d45a0727ce7b15a58dcdd13096c8d5513a9e48))
* **migration:** construct ELASTICSEARCH_URL for reindex step ([fa117b9](https://github.com/bonanzahq/bonanza/commit/fa117b988e58f8156e2f2fb1ef82478444f6018a))
* **migration:** handle unique index conflicts and dynamic count validation ([3b65bd4](https://github.com/bonanzahq/bonanza/commit/3b65bd49b5aa612f8357a381efa3ddebdd947231))
* **migration:** read ELASTICSEARCH_URL from container process env ([bf9b3c5](https://github.com/bonanzahq/bonanza/commit/bf9b3c5a18e6ba92dad384d9baec44403b6e8b49))
* **migration:** URL-encode ES password for reindex step ([abc5eab](https://github.com/bonanzahq/bonanza/commit/abc5eab892bf541e5ad48f6401896140043889fe))
* **search:** guard ParentItem#search_data against nil department ([0b3d7bc](https://github.com/bonanzahq/bonanza/commit/0b3d7bcb8754ce5dd03cd4d80dd1d0369a1f9566)), closes [ParentItem#search_data](https://github.com/ParentItem/issues/search_data)


### Features

* **migration:** add standalone migration scripts for staging/production ([5870f53](https://github.com/bonanzahq/bonanza/commit/5870f533cf40956bcce12705002c71fdc8637b0e))
* **migration:** rename catch-all department to Ponderosa, create setup admin ([76f16d0](https://github.com/bonanzahq/bonanza/commit/76f16d00886c275c0dbb16b69802eca6c4c47a29))

# [2.0.0-beta.4](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.3...v2.0.0-beta.4) (2026-03-04)


### Bug Fixes

* build missing department memberships in user edit action ([b130928](https://github.com/bonanzahq/bonanza/commit/b13092870cb686be8026539eca2337535675b16a))
* update anonymize tests for ALLOW_ANONYMIZE env var guard ([6086989](https://github.com/bonanzahq/bonanza/commit/6086989d19875553100229a259b9188ede89b536))
* use ALLOW_ANONYMIZE env var instead of Rails.env check ([4cfb532](https://github.com/bonanzahq/bonanza/commit/4cfb5324b64fe12f6e89ec2866a52d61e7ae0170))

# [2.0.0-beta.3](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.2...v2.0.0-beta.3) (2026-03-02)


### Bug Fixes

* **ci:** add workflow_dispatch trigger to release workflow ([ae3d613](https://github.com/bonanzahq/bonanza/commit/ae3d61396d7970580448bff88300bf1cb86ff130))


### Features

* add staging:anonymize rake task ([4f87c7c](https://github.com/bonanzahq/bonanza/commit/4f87c7c7ac86ca513880b025505e0e76766a8bb2))

# [2.0.0-beta.2](https://github.com/bonanzahq/bonanza/compare/v2.0.0-beta.1...v2.0.0-beta.2) (2026-03-02)


### Bug Fixes

* **ci:** use release event instead of tag push for versioned Docker builds ([3b27d94](https://github.com/bonanzahq/bonanza/commit/3b27d94d9a9de9c3954326d3d222a89ada8f6979))

# [2.0.0-beta.1](https://github.com/bonanzahq/bonanza/compare/v1.0.0...v2.0.0-beta.1) (2026-03-02)


* feat!: Bonanza v2 ([fa8c04f](https://github.com/bonanzahq/bonanza/commit/fa8c04fe872748eb04c11f428bbb7abfff0638bc))


### Bug Fixes

* **package:** add version field and fix private type ([56b433d](https://github.com/bonanzahq/bonanza/commit/56b433d44e481fdeff08832b37734743e86f5018))


### Features

* **release:** add semantic-release with beta prerelease channel ([acc7b8a](https://github.com/bonanzahq/bonanza/commit/acc7b8a26307e7337e0b2cbca23ffdb7bcebeb19))


### BREAKING CHANGES

* Establishes the v2 release line for the Bonanza rewrite.
