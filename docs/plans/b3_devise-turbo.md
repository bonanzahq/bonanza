# Devise + Hotwire/Turbo Integration Review

## Context

Project uses:
- Devise 4.9.2 for authentication
- Turbo Rails ~> 1.3 for Hotwire SPA-like behavior

Devise 4.9.0+ changed how it integrates with Turbo. Need to review and ensure proper configuration.

## Background: Why This Matters

**Turbo Changes Form Behavior:**
- Turbo intercepts all form submissions and makes them AJAX requests
- Returns Turbo Stream responses instead of full page reloads
- Devise was designed for traditional form submissions with redirects

**Breaking Changes:**
- Sign in/sign up forms might not work correctly
- Flash messages might not display
- Redirects after authentication might fail
- Error messages might not appear

## Review Tasks

### Phase 1: Understand Current Setup

#### 1.1 Read Devise Changelog
- [ ] Review changelog: https://github.com/heartcombo/devise/blob/main/CHANGELOG.md
- [ ] Focus on 4.9.0 changes related to Turbo
- [ ] Note any breaking changes or required configuration

#### 1.2 Read Upgrade Guide
- [ ] Review upgrade guide: https://github.com/heartcombo/devise/wiki/How-To:-Upgrade-to-Devise-4.9.0-%5BHotwire-Turbo-integration%5D
- [ ] Document required configuration changes
- [ ] Check for view changes needed

#### 1.3 Audit Current Devise Setup
- [ ] Check `config/initializers/devise.rb` for Turbo-related settings
- [ ] Review Devise views (if customized): `app/views/devise/`
- [ ] Check if `turbo_confirms_with_devise` is configured
- [ ] Look for any custom Devise controllers

### Phase 2: Configuration Review

#### 2.1 Devise Initializer
Check `config/initializers/devise.rb` for:
- [ ] `config.navigational_formats` - Should include `:turbo_stream`?
- [ ] `config.responder` settings
- [ ] Any Turbo-specific configuration

#### 2.2 Devise Views
Check if views exist and need Turbo attributes:
- [ ] `app/views/devise/sessions/new.html.erb` (sign in)
- [ ] `app/views/devise/registrations/new.html.erb` (sign up)
- [ ] `app/views/devise/registrations/edit.html.erb` (edit profile)
- [ ] `app/views/devise/passwords/` (password reset)
- [ ] `app/views/devise/invitations/` (if using devise_invitable)

Forms might need:
```erb
<%= form_for(resource, data: { turbo: false }) do |f| %>
```
or
```erb
<%= form_for(resource, html: { data: { turbo: false } }) do |f| %>
```

#### 2.3 Flash Messages
- [ ] Check if flash messages display correctly with Turbo
- [ ] Verify flash messages in `app/views/layouts/application.html.erb`
- [ ] May need Turbo Stream template for flashes

#### 2.4 Redirects
Check controllers for redirects after authentication:
- [ ] `app/controllers/application_controller.rb` - `after_sign_in_path_for`
- [ ] Check if redirects work with Turbo navigation

### Phase 3: Testing

#### 3.1 Manual Testing Checklist
- [ ] Sign in functionality works
- [ ] Sign out functionality works
- [ ] Sign up (registration) works
- [ ] Password reset flow works
- [ ] Edit profile works
- [ ] User invitation flow works (devise_invitable)
- [ ] Flash messages display correctly
- [ ] Redirects work as expected
- [ ] Error messages display for invalid inputs

#### 3.2 Turbo-Specific Testing
- [ ] Forms submit via Turbo (check network tab - should be AJAX)
- [ ] Or forms explicitly disable Turbo (check for `data-turbo="false"`)
- [ ] No page refreshes on form submission (unless intended)
- [ ] Browser back/forward works correctly

### Phase 4: Fix Issues

#### 4.1 Common Fixes

**Option A: Disable Turbo on Devise forms** (simpler, traditional behavior)
```erb
<%= form_for(resource, data: { turbo: false }) do |f| %>
```

**Option B: Make Devise Turbo-compatible** (more modern, but complex)
- Add Turbo Stream responses to Devise controllers
- Update views to work with Turbo
- Configure `turbo_confirms_with_devise`

#### 4.2 Recommended Approach
For this project, recommend **Option A** (disable Turbo on Devise forms) because:
- Simpler to implement
- More reliable
- Authentication forms don't need SPA behavior
- Can iterate later if needed

### Phase 5: Documentation

#### 5.1 Document Decisions
- [ ] Document which approach was chosen (A or B)
- [ ] Document any custom configuration
- [ ] Update CLAUDE.md if relevant
- [ ] Add notes to journal

#### 5.2 Update Code Comments
- [ ] Add comments to any modified Devise views explaining Turbo behavior
- [ ] Document any initializer changes

## Files to Review

### Configuration
- `config/initializers/devise.rb`
- `config/routes.rb` (Devise routes)

### Views (if customized)
- `app/views/devise/sessions/`
- `app/views/devise/registrations/`
- `app/views/devise/passwords/`
- `app/views/devise/invitations/` (devise_invitable)
- `app/views/layouts/application.html.erb`

### Controllers (if customized)
- `app/controllers/application_controller.rb`
- `app/controllers/users/` (custom Devise controllers)

## Key Questions to Answer

1. **Are Devise views customized?**
   - If no: May work out of box with Devise 4.9+
   - If yes: Need to check for Turbo compatibility

2. **How should authentication forms behave?**
   - With Turbo (AJAX, no page reload)
   - Without Turbo (traditional, full page reload) ← Recommended

3. **Are there custom Devise controllers?**
   - Check `app/controllers/users/` for invitations_controller.rb
   - May need to handle Turbo responses

4. **What is current user experience?**
   - Are authentication flows working correctly now?
   - Any reported issues with sign in/sign up?

## Expected Outcomes

### Success Criteria
- [ ] All Devise authentication flows work correctly
- [ ] Flash messages display as expected
- [ ] No JavaScript errors in console
- [ ] Redirects work after authentication
- [ ] User experience is smooth (no weird behaviors)
- [ ] Documentation is updated

### Potential Issues to Watch For
- Sign in form submits but nothing happens
- Flash messages don't appear
- Redirects fail silently
- Browser back button doesn't work correctly
- Error messages not displaying

## Implementation Priority

**Priority: Medium**
- Not blocking containerization work
- Should be addressed before production deployment
- May affect user onboarding/authentication experience

**Timing:**
- Can be done in parallel with Docker work
- Should be completed before deploying to production
- Test thoroughly in containerized environment

## Resources

- [Devise Changelog](https://github.com/heartcombo/devise/blob/main/CHANGELOG.md)
- [Upgrade Guide](https://github.com/heartcombo/devise/wiki/How-To:-Upgrade-to-Devise-4.9.0-%5BHotwire-Turbo-integration%5D)
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Devise + Turbo Discussion](https://github.com/heartcombo/devise/discussions)

## Next Steps

1. Generate Devise views if not already customized: `rails generate devise:views`
2. Review the upgrade guide thoroughly
3. Test authentication flows manually
4. Implement fixes if needed
5. Document approach in journal
