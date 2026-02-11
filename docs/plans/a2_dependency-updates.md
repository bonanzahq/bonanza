# Dependency Update Plan

**Status**: CRITICAL - Both Ruby and Rails are End-of-Life

## Executive Summary

Bonanza Redux is running on unsupported, end-of-life software.

- Ruby 3.1.2: EOL since January 2026
- Rails 7.0.4.3: EOL since June 2025

**Target Versions**:
- Ruby 3.4.x (or 3.5.x if stable -- released Dec 2025)
- Rails 8.0.4+ or 8.1.x

**Timeline**: 2.5-4 weeks full-time development

---

## Current State Analysis

### Ruby & Rails Versions

| Component | Current Version | EOL Date | Status |
|-----------|----------------|----------|--------|
| Ruby | 3.1.2 | January 2026 | EOL |
| Rails | 7.0.4.3 | June 2025 | EOL |

### Risk Assessment

**Critical Security Risk**: Ruby 3.1 reached EOL in January 2026. No security patches will be released.

**Rails Security Risk**: Rails 7.0 stopped receiving security patches in June 2025.

**Legal/Compliance Risk**: Running EOL software may violate:
- Security compliance requirements
- Data protection regulations (GDPR)
- University IT policies

**Recommendation**: This is not a "nice to have" upgrade. This is a critical security issue requiring immediate attention.

---

## Update Strategy

This plan organizes updates into two priority tiers:

1. **Critical Updates** - Security risks, must do immediately
2. **Important Updates** - High value, low risk, should do soon

---

## Priority 1: Critical Updates (MUST DO IMMEDIATELY)

### 1.1 Ruby Version Update

**Current**: Ruby 3.1.2 (EOL January 2026)
**Target**: Ruby 3.4.x (or 3.5.x if stable)
**Alternative**: Ruby 3.3.6 (if conservative)

**Urgency**: 🔴🔴 CRITICAL - 18 months without security patches

#### Why Ruby 3.4?

| Version | Released | EOL | Months of Support | Status |
|---------|----------|-----|-------------------|--------|
| 3.1.x | Apr 2022 | Mar 2024 | **EOL** | ❌ No support |
| 3.2.x | Dec 2022 | Mar 2026 | 5 months | ⚠️ Too short |
| **3.3.6** | Dec 2023 | Mar 2027 | **17 months** | ✅ Acceptable |
| **3.4.1** | Dec 2024 | Mar 2028 | **29 months** | ✅ **Recommended** |
| 3.5.x | Dec 2025 | Dec 2028 | Not yet released | ⏳ Coming in 2 months |

**Recommendation**: Ruby 3.4.x (use latest patch at time of upgrade; evaluate 3.5.x stability)

**Why?**
- Released December 2024 (10 months ago)
- Proven stable in production
- All major gems are compatible
- 29 months of security support
- Significant performance improvements (15-20% faster YJIT)

**Conservative Alternative**: Ruby 3.3.6
- Still acceptable with 17 months of support
- More battle-tested
- Lower risk
- **Minimum acceptable version**

#### Ruby 3.4 Benefits

**Performance**:
- 15-20% faster than Ruby 3.3 with YJIT enabled
- Improved garbage collection
- Better memory management
- Modular GC support

**Language Features**:
- `it` block parameter syntax
- Better pattern matching
- Performance improvements in String, Array, Hash

**Stability**:
- 10 months in production use
- Major bugs fixed in 3.4.1 release
- Ecosystem fully compatible

#### Breaking Changes

**Minimal Breaking Changes**:
- Some obscure features removed
- Refinements behavior changes (unlikely to affect this app)
- Most code will work unchanged

**Gems Compatibility**: All gems in Gemfile are compatible with Ruby 3.4

#### Implementation Steps

1. **Update Ruby version files**:
   ```bash
   echo "3.4.1" > .ruby-version
   ```

2. **Update Gemfile**:
   ```ruby
   ruby "3.4.1"
   ```

3. **Update Docker configuration**:
   ```dockerfile
   FROM ruby:3.4.1-alpine
   ```

4. **Update mise.toml** (if used):
   ```toml
   [tools]
   ruby = "3.4.1"
   ```

5. **Install and test**:
   ```bash
   bundle install
   bin/rails server
   # Test all functionality
   ```

6. **Check for warnings**:
   ```bash
   RUBYOPT="-W:deprecated" bin/rails console
   ```

**Estimated Effort**: 2-3 days
- 4 hours: Update configuration
- 8-12 hours: Test all functionality
- 4-8 hours: Fix any compatibility issues (expect minimal)

**Testing Checklist**:
- [ ] Application starts without errors
- [ ] All routes accessible
- [ ] Elasticsearch searches work
- [ ] User authentication works
- [ ] Database queries work
- [ ] Asset pipeline works
- [ ] No deprecation warnings in logs

**Rollback Plan**:
- Keep Ruby 3.1.2 Docker image tagged
- Can revert all version files via git
- Document any code changes needed

---

### 1.2 Rails Version Update

**Current**: Rails 7.0.4.3 (EOL June 2025)
**Target**: Rails 8.0.x
**Alternative**: Rails 7.2.x (if conservative)

**Urgency**: 🔴 CRITICAL - 4 months without security patches

#### Why Rails 8.0?

| Version | Released | EOL | Months of Support | Status |
|---------|----------|-----|-------------------|--------|
| 7.0.x | Dec 2021 | Jun 2025 | **EOL** | ❌ No support |
| **7.2.x** | Aug 2024 | Aug 2027 | **22 months** | ✅ Acceptable |
| **8.0.x** | Dec 2024 | Dec 2027 | **26 months** | ✅ **Recommended** |
| 8.1.x | ~Dec 2025 | ~Dec 2028 | Not yet released | ⏳ Beta phase |

**Recommendation**: Rails 8.0.x (likely 8.0.3 or 8.0.4 by now)

**Why?**
- Released December 2024 (10 months ago)
- Production-proven by thousands of applications
- All major gems updated for compatibility
- 26 months of security support
- Modern features and performance improvements

**Conservative Alternative**: Rails 7.2.x
- 22 months of support (still good)
- Fewer breaking changes
- More conservative upgrade path
- **Minimum acceptable version**

**Why Skip Rails 7.1?**
- Rails 7.1 EOL ~September 2026 (only 11 months)
- Not worth the intermediate step
- Better to go directly to 7.2 or 8.0

#### Rails 8.0 New Features

**Built-in Features** (all optional):
- **Solid Queue**: Background job processing (alternative to Sidekiq)
- **Solid Cache**: Caching backend
- **Solid Cable**: WebSocket connections
- **Rails Authentication**: Simple built-in auth (can keep Devise)
- **Propshaft**: Modern asset pipeline (can keep Sprockets)
- **Kamal**: Deployment tools

**Performance Improvements**:
- Faster boot times
- Better database query performance
- Improved asset compilation
- Better HTTP/2 support

**Other Improvements**:
- Better Hotwire integration
- Improved error messages
- Better PostgreSQL support
- Enhanced PWA capabilities

#### Key Point: Rails 8 Features are Opt-In

**You can upgrade to Rails 8 and continue using**:
- Devise (instead of Rails 8 authentication)
- Sprockets (instead of Propshaft)
- Clockwork (instead of Solid Queue for scheduling)
- Current asset pipeline

This makes the upgrade less risky - you get security patches without forced architecture changes.

#### Breaking Changes (7.0 → 8.0)

**Configuration Changes**:
- New defaults file structure
- Some deprecated features removed
- New framework defaults

**Asset Pipeline**:
- Propshaft is new default (but can opt-out)
- Can keep using Sprockets with config

**Authentication**:
- New authentication generator (but can keep Devise)

**Database**:
- Better PostgreSQL type support
- Some query interface changes

**Mitigations**:
- Most changes are opt-in via configuration
- Can use "compatibility mode" for gradual migration
- `rails app:update` provides new configs you can merge

#### Two Upgrade Approaches

**Approach A: Direct to Rails 8 (Recommended)**

Pros:
- One upgrade instead of two
- Get latest features immediately
- Longer support timeline
- Rails 8 has been stable for 10 months

Cons:
- More changes to test
- Larger version jump
- Need to configure opt-outs for new features

Timeline: 4-7 days

**Approach B: Staged Upgrade (Conservative)**

1. Rails 7.0 → 7.2 (3-4 days)
2. Test in staging (1 week)
3. Rails 7.2 → 8.0 (3-4 days)
4. Test in staging (1-2 weeks)

Pros:
- Lower risk per step
- Can stop at Rails 7.2 if needed
- Easier to identify issues

Cons:
- Takes 2+ weeks longer
- Two separate testing cycles
- More total work

Timeline: 6-8 days + 3 weeks staging

**Recommendation**: Approach A (Direct to Rails 8)

Rails 8 has been out for 10 months, the community has validated it, and most issues have been resolved. The time savings and longer support make the direct upgrade preferable.

#### Implementation Steps

1. **Update Gemfile**:
   ```ruby
   gem "rails", "~> 8.0.0"
   ```

2. **Update gems**:
   ```bash
   bundle update rails
   ```

3. **Run app update**:
   ```bash
   rails app:update
   ```
   This will:
   - Show new configuration files
   - Ask you to merge changes
   - Update framework defaults

4. **Review config changes carefully**:
   - Don't blindly accept all changes
   - Review each file diff
   - Keep customizations
   - Opt-out of new features initially

5. **Configure opt-outs** (in `config/application.rb`):
   ```ruby
   # Keep using Sprockets instead of Propshaft
   config.assets.enabled = true

   # Keep using existing authentication (Devise)
   # No additional config needed

   # Don't enable Solid Queue yet
   # (will continue using clockwork)
   ```

6. **Update initializers**:
   - Check for deprecated code
   - Update any Rails-specific patterns

7. **Test thoroughly**:
   ```bash
   bin/rails server
   # Test all functionality
   ```

8. **Check deprecation warnings**:
   ```bash
   RUBYOPT="-W:deprecated" bin/rails console
   ```

**Estimated Effort**: 4-7 days
- 1 day: Update Rails, run app:update
- 1-2 days: Review and merge config changes
- 1-2 days: Update deprecated code
- 1-2 days: Full testing

**Testing Checklist**:
- [ ] Application starts without errors
- [ ] All routes work
- [ ] Authentication (login/logout) works
- [ ] Authorization (roles) works
- [ ] Database queries work
- [ ] Elasticsearch searches work
- [ ] Asset pipeline compiles
- [ ] Emails can be sent
- [ ] Forms submit correctly (Turbo)
- [ ] Modals work
- [ ] File uploads work
- [ ] All critical user flows work

**Rollback Plan**:
- Git branch for upgrade
- Tag current production version
- Can revert entire branch if needed
- Keep database backup
- Restore config files from backup

---

### 1.3 Critical Security Gem Updates

**Urgency**: 🔴 CRITICAL

After updating Ruby and Rails, run a security audit and update gems with known vulnerabilities.

#### Process

1. **Install bundle-audit**:
   ```bash
   gem install bundler-audit
   ```

2. **Update vulnerability database**:
   ```bash
   bundle audit update
   ```

3. **Run security scan**:
   ```bash
   bundle audit check
   ```

4. **Review reported vulnerabilities**:
   - Read each CVE description
   - Assess impact on your application
   - Check if vulnerability affects your usage

5. **Update affected gems**:
   ```bash
   bundle update <gem-name>
   ```

6. **Re-run audit until clean**:
   ```bash
   bundle audit check
   # Should report: No vulnerabilities found
   ```

#### Critical Gems to Monitor

These gems commonly have security updates:

- **nokogiri** - XML/HTML parser (frequent CVEs)
- **rack** - Web server interface
- **actionpack** - Part of Rails
- **devise** - Authentication
- **loofah** - HTML sanitizer

**Estimated Effort**: 4-8 hours
- 1 hour: Setup and run audit
- 2-4 hours: Review vulnerabilities
- 1-2 hours: Update gems and test
- 1 hour: Re-audit and verify

---

## Priority 2: Important Updates (SHOULD DO SOON)

These updates should be done soon after the critical updates, ideally within the same release cycle.

### 2.1 Searchkick & Elasticsearch

**Current Versions**:
- searchkick: ~5.2
- elasticsearch: 8.4.0

**Target Versions**:
- searchkick: ~5.4 (latest stable)
- elasticsearch: ~8.15 (latest 8.x)

**Why Update**:
- Bug fixes in searchkick
- Performance improvements
- Security patches in Elasticsearch 8.4 → 8.15
- Better Rails 8 compatibility
- Improved search features

**Breaking Changes**: None expected (minor version updates)

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   gem 'searchkick', '~> 5.4'
   gem 'elasticsearch', '~> 8.15'
   ```

2. **Update gems**:
   ```bash
   bundle update searchkick elasticsearch
   ```

3. **Reindex data** (recommended):
   ```bash
   bundle exec rails console
   ParentItem.reindex
   Borrower.reindex
   ```

4. **Test search functionality**:
   - Item search
   - Borrower search
   - Autocomplete
   - Filters
   - Synonyms

**Estimated Effort**: 1-2 days
- 2 hours: Update gems
- 2-4 hours: Reindex and test
- 2-4 hours: Fix any search issues

**Risk**: LOW - Well-maintained gems, backward compatible

---

### 2.2 Authentication & Authorization Gems

**Current Versions**:
- devise: 4.9.2
- devise_invitable: 2.0.7
- cancancan: 3.3.0

**Target Versions**:
- devise: ~4.9.4 (latest stable)
- devise_invitable: ~2.0.9 (latest)
- cancancan: ~3.6.1 (latest)

**Why Update**:
- Security patches in devise
- Bug fixes
- Better Turbo compatibility (devise 4.9.3+)
- Better Rails 8 compatibility

**Breaking Changes**: None expected (patch/minor updates)

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   gem "devise", "~> 4.9"
   gem "devise_invitable", "~> 2.0"
   gem "cancancan", "~> 3.6"
   ```

2. **Update gems**:
   ```bash
   bundle update devise devise_invitable cancancan
   ```

3. **Test authentication flows**:
   - User login/logout
   - Password reset
   - User invitations
   - Email confirmations
   - Authorization rules (all roles)

**Estimated Effort**: 1 day
- 2 hours: Update gems
- 4-6 hours: Test all auth flows

**Risk**: LOW - Patch/minor updates, well-tested

**Note**: Consider reviewing the Devise + Turbo integration plan (docs/plans/b3_devise-turbo.md) at the same time.

---

### 2.3 Hotwire Stack (Turbo & Stimulus)

**Current Versions**:
- turbo-rails: ~1.3
- stimulus-rails: ~1.3

**Target Versions**:
- turbo-rails: ~1.5 (latest)
- stimulus-rails: ~1.3 (latest)

**Why Update**:
- Better Turbo Drive behavior
- Bug fixes with forms and frames
- Better Rails 8 compatibility
- Improved error handling
- Better mobile support

**Breaking Changes**:
- Turbo 1.4+ changed some frame behaviors
- May need to adjust data attributes
- Form submission behavior changes

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   gem "turbo-rails", "~> 1.5"
   gem "stimulus-rails", "~> 1.3"
   ```

2. **Update gems**:
   ```bash
   bundle update turbo-rails stimulus-rails
   ```

3. **Update JavaScript**:
   ```bash
   bin/rails turbo:install:redis
   # If using ActionCable for Turbo Streams
   ```

4. **Test all Turbo interactions**:
   - Forms submissions
   - Turbo Frames
   - Turbo Streams (if used)
   - Navigation
   - Modals

**Estimated Effort**: 2-3 days
- 2 hours: Update gems
- 8-16 hours: Test all Turbo interactions
- 4-8 hours: Fix any issues

**Risk**: MEDIUM - Turbo can have subtle breaking changes

**Recommendation**: This overlaps with the Devise + Turbo review plan. Consider doing both together.

---

### 2.4 Puma Web Server

**Current Version**: ~5.0

**Target Version**: ~6.4 (latest stable)

**Why Update**:
- Performance improvements
- Better memory management
- Security fixes
- Better debugging tools
- Better handling of slow clients

**Breaking Changes**:
- Minor configuration changes
- May need to adjust `config/puma.rb`

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   gem "puma", "~> 6.4"
   ```

2. **Update gem**:
   ```bash
   bundle update puma
   ```

3. **Review config/puma.rb**:
   ```ruby
   # Puma 6 defaults are good, minimal changes needed
   # Check for any deprecated options
   ```

4. **Test**:
   ```bash
   bin/rails server
   # Load test if possible
   ```

**Estimated Effort**: 1 day
- 2 hours: Update and test
- 2-4 hours: Load testing and monitoring

**Risk**: LOW - Minor version update

---

### 2.5 Asset Pipeline & Build Tools

**Current Versions**:
- jsbundling-rails
- cssbundling-rails
- sprockets-rails

**Target Versions**: Latest stable

**Why Update**:
- Build performance improvements
- Better error messages
- Support for newer JS/CSS features
- Better Rails 8 compatibility

**Breaking Changes**: Minimal

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   gem "jsbundling-rails"
   gem "cssbundling-rails"
   gem "sprockets-rails"
   ```

2. **Update gems**:
   ```bash
   bundle update jsbundling-rails cssbundling-rails sprockets-rails
   ```

3. **Update JavaScript dependencies**:
   ```bash
   pnpm update
   ```

4. **Test asset compilation**:
   ```bash
   bin/rails assets:precompile
   ```

**Estimated Effort**: 1 day
- 2 hours: Update gems
- 2-4 hours: Test asset pipeline

**Risk**: LOW

---

### 2.6 Development Tools (RuboCop)

**Current Versions**:
- rubocop
- rubocop-rails
- rubocop-performance

**Target Versions**:
- rubocop: ~1.69 (latest)
- rubocop-rails: ~2.27 (latest)
- rubocop-performance: ~1.23 (latest)

**Why Update**:
- New cops for Ruby 3.4 syntax
- Rails 8 best practices
- Better code quality checks
- Performance suggestions

**Breaking Changes**:
- New cops will flag existing code
- Can be auto-fixed with `rubocop -a`
- May need to update `.rubocop_todo.yml`

**Implementation**:

1. **Update Gemfile**:
   ```ruby
   group :development do
     gem "rubocop", "~> 1.69", require: false
     gem "rubocop-rails", "~> 2.27", require: false
     gem "rubocop-performance", "~> 1.23", require: false
   end
   ```

2. **Update gems**:
   ```bash
   bundle update rubocop rubocop-rails rubocop-performance
   ```

3. **Run RuboCop**:
   ```bash
   bundle exec rubocop
   ```

4. **Auto-fix safe issues**:
   ```bash
   bundle exec rubocop -a
   ```

5. **Regenerate todo file** (if needed):
   ```bash
   bundle exec rubocop --auto-gen-config
   ```

**Estimated Effort**: 2-3 hours

**Risk**: NONE (development-only tools)

---

---

## Update Sequence & Timeline

### Phase 1: Critical Updates (Week 1-3)

**Duration**: 2.5-3.5 weeks
**Effort**: 56-96 hours

#### Week 1: Ruby Update
**Days 1-3**: Ruby 3.1.2 → 3.4.x
- Day 1: Update configuration, install
- Day 2: Test all functionality
- Day 3: Fix issues, final testing

**Verify**: Run test suite, boot containerized app, confirm login page renders

#### Week 2-3: Rails Update
**Days 4-10**: Rails 7.0 → 8.0
- Day 4: Update Rails, run app:update
- Day 5-6: Review and merge config changes
- Day 7-8: Update deprecated code
- Day 9-10: Full testing

**Verify**: Run test suite, boot containerized app, test critical flows

#### Day 11-12: Security Audit
- Run bundle audit
- Update critical gems
- Final security review

**Success Criteria**:
- [ ] Ruby 3.4.1 running in containers
- [ ] Rails 8.0.x running in containers
- [ ] All manual tests pass
- [ ] Zero critical security vulnerabilities
- [ ] No deprecation warnings
- [ ] Performance metrics stable or improved

---

### Phase 2: Important Updates (Week 4-5)

**Duration**: 1.5-2 weeks
**Effort**: 40-56 hours

#### Week 4
- Days 1-2: Searchkick & Elasticsearch
- Day 3: Devise & Authentication
- Days 4-5: Hotwire Stack (Turbo/Stimulus)

#### Week 5
- Day 1: Puma
- Day 2: Asset Pipeline
- Day 3: Development Tools (RuboCop)
- Days 4-5: Final testing (test suite + containerized app)

**Success Criteria**:
- [ ] All gems updated
- [ ] All features working
- [ ] No deprecation warnings
- [ ] Performance improved
- [ ] Ready for production

---

### Phase 3: Production Deployment (Week 6)

**Duration**: 1 week (including monitoring)

#### Pre-Deployment
- [ ] Backup production database
- [ ] Backup production files (ActiveStorage)
- [ ] Document rollback procedure
- [ ] Schedule maintenance window
- [ ] Notify users of maintenance

#### Deployment
- [ ] Deploy to production
- [ ] Monitor error logs
- [ ] Check performance metrics
- [ ] Verify all critical flows
- [ ] Monitor for 24 hours

#### Post-Deployment
- [ ] Monitor for 1 week
- [ ] Address any issues
- [ ] Document lessons learned
- [ ] Update runbooks

---

---

---

## Testing Strategy

### Automated Test Suite

The test suite from a3 (testing infrastructure) covers model tests, controller
tests, and factories for all core models. After each major upgrade step (Ruby
version, Rails version, gem batches), run:

```bash
bin/rails test
```

All tests must pass before proceeding to the next step.

### Container Smoke Test

Since the application is containerized before the dependency upgrade, verify
after each step that the full stack boots and serves pages:

```bash
docker compose up -d
# Wait for health checks to pass, then:
curl -f http://localhost/users/sign_in
# Should return 200 with the login page
```

### Manual Testing Checklist

In addition to automated tests and the container smoke test, manually verify
critical flows before each deployment:

#### Authentication & Authorization
- [ ] Admin login/logout
- [ ] Leader login/logout
- [ ] Member login/logout
- [ ] Guest login/logout
- [ ] Password reset flow
- [ ] User invitation flow
- [ ] Email confirmation
- [ ] Role-based access control (test each role)
- [ ] Department switching

#### Lending Workflow
- [ ] Create new lending (cart state)
- [ ] Add items to cart (autocomplete)
- [ ] Select existing borrower
- [ ] Create new borrower
- [ ] Confirm lending details
- [ ] Complete lending
- [ ] View lending details
- [ ] Print lending agreement
- [ ] Return items (partial)
- [ ] Return items (complete)
- [ ] View lending history

#### Borrower Management
- [ ] List borrowers
- [ ] Search borrowers (Elasticsearch)
- [ ] Register new borrower (self-service)
- [ ] Email confirmation flow
- [ ] View borrower details
- [ ] Edit borrower
- [ ] View borrower lending history
- [ ] Add conduct (warning)
- [ ] Add conduct (ban)
- [ ] Remove conduct

#### Item Management
- [ ] List parent items
- [ ] Search parent items (Elasticsearch)
- [ ] Create parent item
- [ ] Add child items
- [ ] Edit parent item
- [ ] Edit child items
- [ ] Add tags
- [ ] Add accessories
- [ ] Add links
- [ ] Delete/soft-delete items
- [ ] View item history

#### Department Management
- [ ] List departments
- [ ] Create department
- [ ] Edit department
- [ ] Add staff member
- [ ] Remove staff member
- [ ] Change user role
- [ ] Staff department (make active)
- [ ] Unstaff department (make inactive)

#### Search Functionality
- [ ] Item search (basic)
- [ ] Item search (filters)
- [ ] Item search (synonyms)
- [ ] Item autocomplete
- [ ] Borrower search
- [ ] Borrower autocomplete

#### Edge Cases
- [ ] Lending with unavailable items
- [ ] Return overdue items
- [ ] Borrower with multiple active lendings
- [ ] Department with no staff
- [ ] Items with no parent
- [ ] Items with complex accessories

### Performance Testing

Track these metrics before and after upgrade:

- Page load time (homepage)
- Item search response time
- Lending creation time
- Asset compilation time
- Database query time
- Memory usage
- CPU usage

### Browser Testing

Test in multiple browsers:
- [ ] Chrome/Edge (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Mobile Safari (iOS)
- [ ] Mobile Chrome (Android)

### Mailer Previews

Test all mailer previews (when implemented):
- Access `/rails/mailers` in development
- Preview all email templates
- Test with different data scenarios

---

## Risk Assessment

**Combined upgrade risk**: MEDIUM. The biggest risk is doing both Ruby and Rails major updates together.

**Risk of NOT upgrading**: HIGH. Ruby 3.1 is EOL since Jan 2026, Rails 7.0 since June 2025. No security patches for either. Compliance/legal risk with GDPR.

**Verdict**: The risk of upgrading is lower than the risk of staying on EOL software.

---

## Rollback Procedures

### If Ruby Update Fails

1. **Revert version files**:
   ```bash
   git checkout .ruby-version Gemfile
   ```

2. **Reinstall gems**:
   ```bash
   bundle install
   ```

3. **Rebuild Docker image**:
   ```bash
   docker-compose build rails
   ```

4. **Restart services**:
   ```bash
   docker-compose up
   ```

**Fallback Options**:
- Ruby 3.4 issues → Ruby 3.3.6 (still good)
- Ruby 3.3 issues → Ruby 3.2.x (emergency only, EOL in 5 months)

---

### If Rails Update Fails

1. **Checkout clean state**:
   ```bash
   git checkout Gemfile Gemfile.lock
   ```

2. **Restore config files**:
   ```bash
   git checkout config/
   ```

3. **Reinstall gems**:
   ```bash
   bundle install
   ```

4. **Restart application**:
   ```bash
   docker-compose restart rails
   ```

**Fallback Options**:
- Rails 8.0 issues → Rails 7.2.x (still good)
- Rails 7.2 issues → Rails 7.1.x (emergency only)

---

### If Database Issues Occur

1. **Stop application**:
   ```bash
   docker-compose stop rails
   ```

2. **Restore database from backup**:
   ```bash
   # Use your backup restoration procedure
   ```

3. **Rollback code changes**:
   ```bash
   git reset --hard <previous-commit>
   ```

4. **Restart application**:
   ```bash
   docker-compose up rails
   ```

---

## Configuration Updates

### Update .ruby-version
```
3.4.1
```

### Update Gemfile

```ruby
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.1"

# Core Rails
gem "rails", "~> 8.0.0"
gem "sprockets-rails"

# Database
gem "pg", "~> 1.5"

# Web Server
gem "puma", "~> 6.4"

# Frontend
gem "jsbundling-rails"
gem "turbo-rails", "~> 1.5"
gem "stimulus-rails"
gem "cssbundling-rails"

# Other gems...
gem "bootsnap", require: false
gem "bcrypt", "~> 3.1.7"
gem "jbuilder"

# Bonanza-specific gems
gem "devise", "~> 4.9"
gem "devise_invitable", "~> 2.0"
gem "cancancan", "~> 3.6"
gem "kaminari", "~> 1.2"
gem "pg_search", "~> 2.3"
gem "acts-as-taggable-on", "~> 10.0"
gem "ruby_identicon", "0.0.6"
gem "oj", "~> 3.13"
gem "searchkick", "~> 5.4"
gem "elasticsearch", "~> 8.15"
gem "redcarpet", "~> 3.6"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
  gem "awesome_print"
  gem "seed_dump"
  gem "rubocop", "~> 1.69", require: false
  gem "rubocop-rails", "~> 2.27", require: false
  gem "rubocop-performance", "~> 1.23", require: false
end
```

### Update Dockerfile

```dockerfile
FROM ruby:3.4.1-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    npm \
    git

RUN npm install -g pnpm

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Install JavaScript dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Runtime stage
FROM ruby:3.4.1-alpine

RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    tzdata

WORKDIR /app

# Copy from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Update mise.toml (if using mise)

```toml
[tools]
ruby = "3.4.1"
node = "20"
```

### Update GitHub Actions / CI (if applicable)

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      elasticsearch:
        image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
        env:
          discovery.type: single-node
          xpack.security.enabled: false

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4.1'
          bundler-cache: true

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        run: npm install -g pnpm

      - name: Install dependencies
        run: |
          bundle install
          pnpm install --frozen-lockfile

      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
          ELASTICSEARCH_URL: http://localhost:9200
        run: |
          bundle exec rails test
```

---

## Post-Update Monitoring

### Week 1: Intensive Monitoring

**Daily Tasks**:
- [ ] Review error logs
- [ ] Check application performance
- [ ] Monitor memory usage
- [ ] Review slow queries
- [ ] Check for deprecation warnings
- [ ] Monitor scheduled tasks (if implemented)

**Metrics to Track**:
- Error rate (should be near zero)
- Response times (should be same or better)
- Memory usage (should be same or less)
- Database query performance
- Search performance

### Week 2-4: Regular Monitoring

**2-3x per week**:
- [ ] Review error logs
- [ ] Check performance metrics
- [ ] Review user feedback
- [ ] Monitor background jobs (if implemented)

### Ongoing

**Monthly**:
- [ ] Run bundle audit
- [ ] Check for gem updates
- [ ] Review deprecation warnings
- [ ] Check EOL dates

---

---

## Success Metrics

### Technical Metrics

**Required for Success**:
- [ ] Ruby 3.4.1 running in production (or 3.3.6 minimum)
- [ ] Rails 8.0.x running in production (or 7.2.x minimum)
- [ ] All gems up to date
- [ ] Zero critical security vulnerabilities (bundle audit clean)
- [ ] No deprecation warnings in logs
- [ ] All manual tests pass
- [ ] No regressions in functionality

### Performance Metrics

**Should be stable or improved**:
- [ ] Page load times ≤ baseline
- [ ] Search response times ≤ baseline
- [ ] Database query times ≤ baseline
- [ ] Memory usage ≤ baseline
- [ ] Asset compilation time ≤ baseline

### Business Metrics

**Required**:
- [ ] Zero user-reported bugs related to updates
- [ ] No unplanned downtime
- [ ] All features working as expected
- [ ] User satisfaction maintained

### Security Metrics

**Required**:
- [ ] Zero critical CVEs
- [ ] Zero high CVEs
- [ ] Medium/Low CVEs acceptable with mitigation plan

---

---

## Dependency Matrix

### Update Dependencies

```
Ruby 3.4.1 (MUST DO FIRST)
    ↓
Rails 8.0.x (Depends on Ruby 3.4+)
    ↓
├── Searchkick/Elasticsearch (Independent, but test after Rails)
├── Devise (Independent, but test after Rails)
├── Turbo/Stimulus (May depend on Rails 8, test carefully)
├── Puma (Independent)
└── RuboCop (Independent)
```

**Key Rules**:
1. Ruby MUST be updated before Rails
2. Rails SHOULD be updated before Hotwire
3. All other gems can be updated in any order after Rails

---

## Target Gem Versions

### Core Framework

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| ruby | 3.1.2 | 3.4.x or 3.5.x | Critical |
| rails | 7.0.4.3 | 8.0.4+ or 8.1.x | Critical |
| puma | ~5.0 | ~6.4 | Important |

### Authentication & Authorization

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| devise | 4.9.2 | 4.9.4 | Important |
| devise_invitable | 2.0.7 | 2.0.9 | Important |
| cancancan | 3.3.0 | 3.6.1 | Important |
| bcrypt | 3.1.18 | 3.1.20 | Important |

### Search

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| searchkick | ~5.2 | ~5.4 | Important |
| elasticsearch | 8.4.0 | 8.15.x | Important |
| pg_search | 2.3.0 | 2.3.x | Low |

### Frontend

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| turbo-rails | ~1.3 | ~1.5 | Important |
| stimulus-rails | ~1.3 | ~1.3 | Important |
| jsbundling-rails | latest | latest | Important |
| cssbundling-rails | latest | latest | Important |

### Database

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| pg | ~1.1 | ~1.5 | Important |
| kaminari | 1.2.0 | 1.2.x | Low |
| acts-as-taggable-on | 9.0.1 | 10.0 | Future |

### Development

| Gem | Current | Target | Priority |
|-----|---------|--------|----------|
| rubocop | (check) | ~1.69 | Low |
| rubocop-rails | (check) | ~2.27 | Low |
| rubocop-performance | (check) | ~1.23 | Low |

---

## Resources

- [bundler-audit](https://github.com/rubysec/bundler-audit) - Security scanner
- [RailsDiff](http://railsdiff.org/) - See changes between Rails versions
- [Rails Upgrade Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [RubySec Advisory Database](https://rubysec.com/)

---

## Next Steps

1. Backup production database and files
2. Begin Phase 1 (Ruby + Rails updates)
3. Verify with test suite and containerized app after each step
4. Deploy to production
5. Monitor closely for 1 week post-deployment
6. Monthly security audits with bundle-audit ongoing
