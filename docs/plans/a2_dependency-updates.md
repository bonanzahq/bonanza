# Dependency Update Plan

**Plan Date**: October 6, 2025
**Status**: 🔴🔴 CRITICAL - Both Ruby and Rails are End-of-Life

## Executive Summary

**Bonanza Redux is running on unsupported, end-of-life software with known security vulnerabilities.**

- Ruby 3.1.2: EOL for **18 months** (ended March 2024)
- Rails 7.0.4.3: EOL for **4 months** (ended June 2025)

**Immediate action required.** This document outlines a path to bring the application to supported versions.

**Recommended Target Versions**:
- Ruby 3.4.1 (EOL: March 2028 - 29 months of support)
- Rails 8.0.x (EOL: ~December 2027 - 26 months of support)

**Alternative Conservative Path**:
- Ruby 3.3.6 (EOL: March 2027 - 17 months of support)
- Rails 7.2.x (EOL: August 2027 - 22 months of support)

**Timeline**: 2.5-4 weeks full-time development
**Budget**: 96-152 hours

---

## Current State Analysis

### Ruby & Rails Versions

| Component | Current Version | Released | EOL Date | Status |
|-----------|----------------|----------|----------|--------|
| Ruby | 3.1.2 | April 2022 | March 2024 | 🔴 EOL for 18 months |
| Rails | 7.0.4.3 | March 2023 | June 2025 | 🔴 EOL for 4 months |

### Risk Assessment

**Critical Security Risk**: No security patches have been released for Ruby 3.1 since March 2024. Any discovered vulnerabilities in Ruby 3.1 will not be patched.

**Rails Security Risk**: Rails 7.0 stopped receiving security patches in June 2025. Only severe security issues may receive backports.

**Legal/Compliance Risk**: Running EOL software may violate:
- Security compliance requirements
- Data protection regulations (GDPR)
- University IT policies

**Recommendation**: This is not a "nice to have" upgrade. This is a critical security issue requiring immediate attention.

---

## Update Strategy

This plan organizes updates into three priority tiers:

1. **Critical Updates** - Security risks, must do immediately
2. **Important Updates** - High value, low risk, should do soon
3. **Future Improvements** - Can be deferred 3-6 months

---

## Priority 1: Critical Updates (MUST DO IMMEDIATELY)

### 1.1 Ruby Version Update

**Current**: Ruby 3.1.2 (EOL March 2024)
**Target**: Ruby 3.4.1
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

**Recommendation**: Ruby 3.4.1

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
   yarn upgrade
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

## Priority 3: Future Improvements (NICE TO HAVE)

These can be deferred 3-6 months after the critical updates.

### 3.1 Adopt Rails 8 Native Features

**Timeline**: After successfully upgrading to Rails 8.0

If you upgrade to Rails 8, consider adopting these features gradually:

#### 3.1.1 Solid Queue (Background Jobs)

**Current**: Clockwork for scheduling, synchronous email sending

**Alternative**: Solid Queue (Rails 8 built-in)

**Benefits**:
- Better job management UI
- Built-in retry logic
- Database-backed (no Redis needed)
- Better error handling
- Could replace Clockwork

**When**: After email notification system is implemented and stable

**Estimated Effort**: 2-3 days
- Add Solid Queue
- Migrate scheduled tasks from Clockwork
- Update email sending to use background jobs

**Risk**: LOW - Can run alongside Clockwork initially

#### 3.1.2 Rails 8 Authentication

**Current**: Devise + Devise Invitable

**Alternative**: Rails 8 built-in authentication

**Evaluation**:
- Rails 8 auth is simpler but less feature-rich
- Devise has: invitations, confirmations, lockable, timeoutable, etc.
- **Recommendation**: Keep Devise
- Devise is well-tested and provides features you need

**Decision**: Don't migrate to Rails 8 auth

#### 3.1.3 Propshaft Asset Pipeline

**Current**: Sprockets

**Alternative**: Propshaft (Rails 8 default)

**Benefits**:
- Faster asset compilation
- Simpler configuration
- Better for modern JavaScript

**When**: If asset pipeline becomes a bottleneck

**Estimated Effort**: 2-3 days

**Risk**: MEDIUM - Asset pipeline changes can be tricky

---

### 3.2 Ruby 3.5 Upgrade (Future)

**Timeline**: Q2-Q3 2026 (after Ruby 3.5 matures)

**Ruby 3.5 Details**:
- Releases: December 2025 (2 months away)
- EOL: December 2028
- Will provide 3 years of support

**Recommendation**: Wait 3-6 months after release
- Let ecosystem mature
- Wait for gem compatibility
- Wait for bug fixes (3.5.1, 3.5.2)

**When to Consider**:
- Q2-Q3 2026
- After Ruby 3.5.2+ is released
- When Ruby 3.4 approaches EOL

---

### 3.3 Background Job System

**Current State**: No background job system

**Options**:
1. **Solid Queue** (Rails 8 built-in) - Recommended if on Rails 8
2. **Sidekiq** (industry standard, requires Redis)
3. **Good Job** (PostgreSQL-based)

**Why Add**:
- Better email sending (don't block requests)
- Better scheduled task management
- Better reliability (retries, error handling)
- Job monitoring and debugging

**When to Add**: After email notification system is implemented

**Estimated Effort**:
- Solid Queue: 2-3 days (built-in to Rails 8)
- Sidekiq: 3-5 days (need to add Redis)

---

### 3.4 Testing Framework

**Current State**: No test framework configured

**Options**:
- **Minitest** (Rails default, simpler)
- **RSpec** (behavior-driven development, more features)

**Why Add**:
- Prevent regressions
- Confidence for future updates
- Better documentation of expected behavior

**When to Add**: Before major refactoring projects

**Estimated Effort**: 1-2 weeks
- Set up testing framework
- Write core tests
- Set up CI pipeline

---

### 3.5 Modern Ruby Gems

**Consider replacing/updating**:

1. **ruby_identicon** (0.0.6 - unmaintained since 2014)
   - Alternative: Generate SVG identicons directly
   - Or use jdenticon (JavaScript library)
   - **When**: Low priority, current gem works

2. **acts-as-taggable-on** (9.0.1)
   - Update to 10.x when available
   - Check for breaking changes
   - **When**: After Rails 8 upgrade

---

## Update Sequence & Timeline

### Phase 1: Critical Updates (Week 1-3)

**Duration**: 2.5-3.5 weeks
**Effort**: 56-96 hours

#### Week 1: Ruby Update
**Days 1-3**: Ruby 3.1.2 → 3.4.1
- Day 1: Update configuration, install
- Day 2: Test all functionality
- Day 3: Fix issues, final testing

**Staging**: Deploy to staging, monitor for 2-3 days

#### Week 2-3: Rails Update
**Days 4-10**: Rails 7.0 → 8.0
- Day 4: Update Rails, run app:update
- Day 5-6: Review and merge config changes
- Day 7-8: Update deprecated code
- Day 9-10: Full testing

**Staging**: Deploy to staging, monitor for 1-2 weeks

#### Day 11-12: Security Audit
- Run bundle audit
- Update critical gems
- Final security review

**Success Criteria**:
- [ ] Ruby 3.4.1 running in staging
- [ ] Rails 8.0.x running in staging
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
- Days 4-5: Final testing and staging

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

### Phase 4: Future Improvements (Deferred)

**Timeline**: 3-6 months after Phase 3

- Evaluate Solid Queue adoption
- Consider Propshaft migration
- Add testing framework
- Plan for Ruby 3.5 upgrade (Q2 2026)

---

## Alternative: Conservative Upgrade Path

If the direct Rails 8 upgrade feels too risky, consider this alternative:

### Conservative Phase 1: Minimum Updates

**Week 1-2**:
- Ruby 3.1.2 → 3.3.6 (not 3.4)
- Rails 7.0 → 7.2.x (not 8.0)

**Benefits**:
- Lower risk
- Smaller version jumps
- More proven upgrade path

**Drawbacks**:
- Shorter support timeline (17-22 months)
- Will need to upgrade again sooner
- Miss out on Rails 8 improvements

### Conservative Phase 2: Rails 8 Later

**Q1 2026** (3-4 months later):
- Rails 7.2 → 8.0
- Ruby 3.3 → 3.4 (optional)

**Total Timeline**: 2-3 weeks longer but spreads risk

---

## Testing Strategy

### Challenge: No Automated Tests

The application has no test suite, so we rely entirely on manual testing.

### Manual Testing Checklist

Create a comprehensive checklist and test before each deployment:

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

### Ruby 3.4 Update

**Risk Level**: ⚠️ LOW-MEDIUM

**Risks**:
- Ruby 3.4 is 10 months old but not as proven as 3.3
- Potential edge case bugs
- Gem compatibility (though all major gems support it)

**Mitigation**:
- Test thoroughly in development
- Deploy to staging for 1 week minimum
- Keep Ruby 3.1.2 Docker image available
- Can fallback to Ruby 3.3.6 if serious issues

**Confidence**: HIGH - Ruby 3.4 is stable and production-ready

---

### Rails 8.0 Update

**Risk Level**: ⚠️⚠️ MEDIUM-HIGH

**Risks**:
- Major version bump with significant changes
- New defaults may affect behavior
- Config merge process can be error-prone
- More things to test

**Mitigation**:
- Review all config changes carefully
- Opt-out of new features initially
- Use compatibility mode
- Test in staging for 1-2 weeks minimum
- Can rollback via git
- Can fallback to Rails 7.2 if critical issues

**Confidence**: MEDIUM-HIGH - Rails 8 is proven but this app has no tests

**Alternative**: If this feels too risky, do Rails 7.2 first

---

### Other Gem Updates

**Risk Level**: ✅ LOW

**Risks**: Minimal - mostly minor/patch updates

**Mitigation**: Standard testing, easy to rollback

---

### Overall Risk Assessment

**Combined Risk**: ⚠️⚠️ MEDIUM

The biggest risk is doing both Ruby and Rails major updates together. However:

**Current Risk of NOT Upgrading**: 🔴🔴 HIGH
- 18 months without Ruby security patches
- 4 months without Rails security patches
- Known vulnerabilities likely exist
- Compliance/legal risk

**Verdict**: The risk of upgrading is LOWER than the risk of staying on EOL software.

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
    yarn \
    git

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Install JavaScript dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Runtime stage
FROM ruby:3.4.1-alpine

RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    yarn \
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
          cache: 'yarn'

      - name: Install dependencies
        run: |
          bundle install
          yarn install

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

## Communication Plan

### Before Updates

**Notify**:
- All developers
- Project stakeholders
- System administrators
- End users (schedule maintenance window)

**Communication Template**:
```
Subject: Critical Security Updates - Maintenance Window

We will be performing critical security updates to Bonanza Redux:

What: Upgrading Ruby and Rails to supported versions
When: [Date/Time]
Duration: [Estimated downtime]
Impact: Application will be unavailable during maintenance

Why: Our current Ruby version reached end-of-life 18 months ago,
     and Rails reached EOL 4 months ago. This poses security risks.

What to expect:
- Application unavailable during maintenance window
- All features will work the same after update
- Performance may improve

Rollback plan: If issues occur, we can rollback within 1 hour.

Questions? Contact: [Contact info]
```

### During Updates

**Communication Channel**: Slack/Email

**Updates**:
- Started maintenance window
- Completed Ruby update
- Started Rails update
- Completed updates, testing
- Issues encountered (if any)
- Maintenance window extended (if needed)
- Updates complete, application available

### After Updates

**Report Template**:
```
Subject: Bonanza Redux Updates Complete

The security updates have been completed successfully.

Updates Applied:
- Ruby: 3.1.2 → 3.4.1
- Rails: 7.0.4.3 → 8.0.x
- [List other gems updated]

Results:
- All security vulnerabilities resolved
- [Performance improvements observed]
- [Any issues encountered and resolved]

What Changed:
- [User-visible changes, if any]
- [Feature improvements]

Monitoring:
We will monitor the application closely for the next week.
Please report any issues to [Contact info].

Thank you for your patience.
```

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

## Budget Estimate

### Phase 1: Critical Updates

**Ruby Update**: 16-24 hours
- Configuration: 4 hours
- Testing: 8-12 hours
- Fixes: 4-8 hours

**Rails Update**: 32-56 hours
- Update and config merge: 8-16 hours
- Code updates: 8-16 hours
- Testing: 16-24 hours

**Security Audit**: 8-16 hours
- Initial audit: 2-4 hours
- Gem updates: 4-8 hours
- Final verification: 2-4 hours

**Phase 1 Total**: 56-96 hours

### Phase 2: Important Updates

**Gem Updates**: 32-48 hours
- Searchkick/Elasticsearch: 8-16 hours
- Authentication gems: 8 hours
- Hotwire: 16-24 hours
- Puma: 8 hours
- Asset pipeline: 8 hours
- RuboCop: 2-3 hours

**Phase 2 Total**: 40-56 hours

### Phase 3: Deployment & Monitoring

**Deployment**: 8-16 hours
- Pre-deployment prep: 4-8 hours
- Deployment: 2-4 hours
- Post-deployment: 2-4 hours

**Phase 3 Total**: 8-16 hours

### Grand Total

**Total Hours**: 104-168 hours (2.5-4 weeks)

**Breakdown**:
- Aggressive path (direct to Ruby 3.4 + Rails 8): ~140-168 hours
- Conservative path (staged updates): ~104-120 hours

**Cost Factors**:
- Developer hourly rate
- Staging environment (if not existing)
- Potential rollback time (buffer +20%)
- Testing and QA time

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
| ruby | 3.1.2 | 3.4.1 | Critical |
| rails | 7.0.4.3 | 8.0.x | Critical |
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

## Resources & References

### Official Documentation

**Ruby**:
- [Ruby 3.4.0 Release Notes](https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/)
- [Ruby 3.3.0 Release Notes](https://www.ruby-lang.org/en/news/2023/12/25/ruby-3-3-0-released/)
- [Ruby Maintenance Schedule](https://www.ruby-lang.org/en/downloads/branches/)

**Rails**:
- [Rails 8.0 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)
- [Rails 7.2 Release Notes](https://edgeguides.rubyonrails.org/7_2_release_notes.html)
- [Rails Upgrade Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Rails Maintenance Policy](https://guides.rubyonrails.org/maintenance_policy.html)

### Tools

- [bundler-audit](https://github.com/rubysec/bundler-audit) - Security scanner
- [rails-upgrade-checklist](https://github.com/fastruby/rails-upgrade-checklist)
- [RuboCop](https://rubocop.org/) - Code quality

### Community Resources

- [GoRails](https://gorails.com/) - Rails screencasts
- [RailsDiff](http://railsdiff.org/) - See changes between Rails versions
- [Ruby on Rails Link Slack](https://www.rubyonrails.link/)

### Security

- [RubySec Advisory Database](https://rubysec.com/)
- [Rails Security Mailing List](https://groups.google.com/g/rubyonrails-security)

---

## Conclusion

### Current Situation: CRITICAL

Bonanza Redux is running on:
- Ruby 3.1.2 (EOL for 18 months)
- Rails 7.0.4.3 (EOL for 4 months)

**This is a critical security risk that requires immediate action.**

### Recommended Path

**Priority 1: Critical Updates (Weeks 1-3)**
1. Ruby 3.1.2 → Ruby 3.4.1
2. Rails 7.0 → Rails 8.0
3. Security audit and critical gem updates

**Priority 2: Important Updates (Weeks 4-5)**
4. Update remaining gems (search, auth, frontend, etc.)

**Priority 3: Deploy to Production (Week 6)**
5. Deploy with monitoring

### Alternative Conservative Path

If Rails 8 feels too risky:
1. Ruby 3.1.2 → Ruby 3.3.6
2. Rails 7.0 → Rails 7.2.x
3. Monitor for 2-4 weeks
4. Rails 7.2 → Rails 8.0 (later)

### Timeline

**Aggressive Path**: 4 weeks (104-168 hours)
**Conservative Path**: 6 weeks (with staged Rails update)

### Next Steps

1. **Get stakeholder approval** for maintenance window
2. **Schedule maintenance** window
3. **Backup production** database and files
4. **Begin Phase 1** (Ruby + Rails updates)
5. **Test thoroughly** in staging
6. **Deploy to production** after 1-2 weeks staging
7. **Monitor closely** for 1 week post-deployment

### Long-term

- **Q2 2026**: Consider Ruby 3.5 upgrade
- **2027**: Plan for next major Rails version
- **Ongoing**: Monthly security audits with bundle-audit

---

**This update is not optional. It is a critical security requirement.**

The risk of upgrading is significantly lower than the risk of continuing to run EOL software with known vulnerabilities.
