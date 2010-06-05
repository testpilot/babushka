
dep 'babushka' do
  requires 'babushka in path', 'babushka up to date', 'dep source'
  define_var :install_prefix, :default => '/usr/local', :message => "Where would you like babushka installed"
  define_var :babushka_branch,
    :message => "Which branch would you like to update from?",
    :default => 'master',
    :choice_descriptions => {
      'master' => 'Standard-issue babushka',
      'next' => 'The development head -- slight risk of explosions'
    }
  setup {
    set :install_prefix, Babushka::Path.prefix if Babushka::Path.run_from_path?
    set :babushka_branch, 'master'
  }
end

dep 'babushka up to date' do
  requires 'babushka repo clean', 'babushka update would fast forward'
  met? {
    in_dir(var(:install_prefix) / 'babushka') {
      shell("git rev-list ..origin/#{var :babushka_branch}").lines.to_a.empty?
    }
  }
  meet { in_dir(var(:install_prefix) / 'babushka') { shell("git merge origin/#{var :babushka_branch}", :log => true) } }
end

dep 'babushka update would fast forward' do
  requires 'babushka installed'
  met? {
    in_dir(var(:install_prefix) / 'babushka') {
      if !shell('git fetch')
        fail_because("Couldn't pull the latest code - check your internet connection.")
      else
        shell("git rev-list origin/#{var :babushka_branch}..").lines.to_a.empty? or
        fail_because("There are unpushed commits in #{var(:install_prefix) / 'babushka'}.")
      end
    }
  }
end

dep 'babushka repo clean' do
  requires 'babushka installed'
  met? {
    in_dir(var(:install_prefix) / 'babushka') {
      shell('git ls-files -m').lines.to_a.empty? or
      fail_because("There are local changes in #{var(:install_prefix) / 'babushka'}.")
    }
  }
end

dep 'babushka in path' do
  requires 'babushka installed'
  met? { which 'babushka' }
  meet {
    log_shell "Linking babushka into #{var(:install_prefix) / 'bin'}", %Q{ln -sf "#{var(:install_prefix) / 'babushka/bin/babushka.rb'}" "#{var(:install_prefix) / 'bin/babushka'}"}
  }
end

dep 'dep source' do
  requires 'babushka in path'
  setup {
    define_var :dep_source, :default => (shell('git config github.user') || 'benhoskings'), :message => "Whose deps would you like to install (you can add others' later)"
  }
  met? {
    returning(!(source_count = shell('babushka sources -l').split("\n").reject {|l| l.starts_with? '#' }.length).zero?) do |result|
      log_ok "There #{source_count == 1 ? 'is' : 'are'} #{source_count} dep source#{'s' unless source_count == 1} set up." if result
    end
  }
  meet { shell "babushka sources -a '#{var :dep_source}' 'git://github.com/#{var(:dep_source)}/babushka-deps'", :log => true }
end

dep 'babushka installed' do
  requires 'ruby', 'git'
  setup { set :babushka_source, "git://github.com/benhoskings/babushka.git" }
  met? { git_repo?(var(:install_prefix) / 'babushka') }
  meet {
    in_dir var :install_prefix do |path|
      log_shell "Installing babushka to #{var(:install_prefix) / 'babushka'}", %Q{git clone "#{var :babushka_source}" ./babushka}
    end
  }
end
