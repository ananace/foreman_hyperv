require 'rake/testtask'

namespace :test do
  desc 'Test ForemanHyperv'
  Rake::TestTask.new :foreman_hyperv do |t|
    test_dir = File.join(__dir__, '../..', 'test')
    t.libs << ['test', test_dir]
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
    t.warning = false
  end
end

namespace :foreman_hyperv do
  task :rubocop do
    begin
      require 'rubocop/take_task'
      RuboCop::RakeTask.new :rubocop_foreman_hyperv do |task|
        task.patterns = [
          '/app/**/*.rb',
          '/lib/**/*.rb',
          '/test/**/*.rb'
        ].map { |p| "#{ForemanHyperv::Engine.root}#{p}" }
      end
    rescue StandardError
      puts 'Rubocop not loaded'
    end

    Rake::Task['rubocop_foreman_hyperv'].invoke
  end
end

Rake::Task[:test].enhance ['test:foreman_hyperv']
