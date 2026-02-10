namespace :lint do
  desc "Run RuboCop"
  task :rubocop do
    sh "rubocop"
  end

  desc "Auto-correct RuboCop offenses (safe fixes only)"
  task :fix do
    sh "rubocop -a"
  end

  desc "Auto-correct RuboCop offenses (including unsafe fixes)"
  task :fix_all do
    sh "rubocop -A"
  end
end

desc "Run all linters"
task lint: ["lint:rubocop"]
