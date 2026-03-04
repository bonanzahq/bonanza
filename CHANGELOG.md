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
