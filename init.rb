# Redmine Dashboard
# Copyright (C) 2026 Niltek Arge
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. See the LICENSE file for details.

require_relative 'lib/redmine_dashboard/report'

Redmine::Plugin.register :redmine_dashboard do
  name 'Pano'
  author 'Niltek Arge'
  author_url 'https://github.com/oten52'
  description 'Kayıtlı bir sorgunun sütunlarına göre oransal dağılım gösterir.'
  version '0.2.0'
  url 'https://github.com/oten52/Redmine.Dashboard'
  requires_redmine version_or_higher: '4.2'

  # The git repository folder is Redmine.Dashboard. Point Redmine at this
  # directory so the plugin loads without renaming the clone.
  directory File.expand_path(__dir__)

  menu :top_menu, :redmine_dashboard,
    {:controller => 'redmine_dashboard', :action => 'show'},
    :caption => :redmine_dashboard_menu,
    :after => :projects,
    :if => Proc.new { |_project| User.current.allowed_to?(:view_issues, nil, :global => true) }

  menu :project_menu, :redmine_dashboard,
    {:controller => 'redmine_dashboard', :action => 'show'},
    :caption => :redmine_dashboard_menu,
    :after => :issues,
    :param => :project_id,
    :permission => :view_issues
end
