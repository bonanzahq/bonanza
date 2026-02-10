# Ruby Tools Quick Reference

## Development Server

Start all development processes (Rails server, JS bundler, CSS compiler) with a single command:

```bash
bin/dev
```

This uses Foreman to run processes defined in `Procfile.dev`:
- **web**: Rails server on port 3000
- **js**: esbuild in watch mode
- **css**: Sass compiler in watch mode

Alternatively, run processes individually:
```bash
bin/rails server -p 3000     # Rails server only
pnpm build --watch           # JS bundling
pnpm build:css --watch       # CSS compilation
```

## Production Server

Production deployment uses Puma (Rails application server) with Caddy reverse proxy in Docker containers.

**Architecture:**
- **Caddy container**: Reverse proxy with automatic Let's Encrypt HTTPS certificates
- **Puma container**: Rails application server

Caddy handles SSL/TLS termination and proxies requests to the Puma container running the Rails app.

## Rails Console

Interactive Ruby REPL with full Rails environment loaded. Access to all models, database, and application code.

### Common Commands

| Command | Description |
|---------|-------------|
| `bin/rails console` | Start console in development |
| `bin/rails console production` | Start console in production |
| `bin/rails console -s` | Sandbox mode (rolls back changes on exit) |
| `RAILS_ENV=production irb -r ./config/environment` | Alternative method if bin/rails fails |

**Common console operations:**
```ruby
User.all                     # Get all users
User.count                   # Count records
User.find(1)                 # Find by ID
User.where(role: 3)          # Query with conditions
User.pluck(:id, :email)      # Get specific columns
Department.all               # Query any model
exit                         # Exit console
```

**Creating records:**
```ruby
User.create!(
  first_name: "John",
  last_name: "Doe",
  email: "john@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: 1,
  department_id: 2
)
```

**Note:** Always use sandbox mode (`-s`) in production to avoid accidental changes.

## Testing

No test framework currently configured in this project.

## Bundler (Gem Installation)

Ruby's package manager. Reads `Gemfile` and `Gemfile.lock` to install exact gem versions. Gems install globally per Ruby version (managed by mise), but Bundler ensures each project loads correct versions via `Gemfile.lock`.

### Common Commands

| Command | Description |
|---------|-------------|
| `bundle install` | Install all gems from Gemfile.lock |
| `bundle update` | Update gems and Gemfile.lock |
| `bundle update <gem>` | Update specific gem only |
| `bundle exec <cmd>` | Run command with bundled gem versions |
| `bundle show <gem>` | Show where a gem is installed |
| `bundle outdated` | List gems with newer versions available |
| `bundle clean` | Remove unused gems |

## Rake (Task Runner)

Ruby's task runner and build tool. Similar to npm scripts but more powerful. Tasks defined in `Rakefile` or `lib/tasks/*.rake`. Rails includes many built-in tasks for database, assets, etc.

### Common Commands

| Command | Description |
|---------|-------------|
| `rake -T` | List all available tasks |
| `rake -T <pattern>` | List tasks matching pattern |
| `rake db:migrate` | Run database migrations |
| `rake db:seed` | Seed database with data |
| `rake db:reset` | Drop, create, migrate, seed |
| `rake assets:precompile` | Compile assets for production |
| `rake lint` | Run linters (custom task) |
| `rake lint:fix` | Auto-fix linting issues (custom) |

## RuboCop (Linter & Formatter)

Ruby linter and formatter. Like ESLint + Prettier combined. Enforces style guidelines and catches potential bugs. Config in `.rubocop.yml`, violations disabled in `.rubocop_todo.yml`.

### Common Commands

| Command | Description |
|---------|-------------|
| `rubocop` | Check all files for violations |
| `rubocop -a` | Auto-fix safe violations |
| `rubocop -A` | Auto-fix all violations (unsafe too) |
| `rubocop <file>` | Check specific file |
| `rubocop --auto-gen-config` | Generate .rubocop_todo.yml |
| `rake lint` | Check via rake task |
| `rake lint:fix` | Auto-fix safe via rake task |
| `rake lint:fix_all` | Auto-fix all via rake task |

### Configuration Files

| File | Purpose |
|------|---------|
| `.rubocop.yml` | Main configuration |
| `.rubocop_todo.yml` | Auto-generated violations to ignore |
