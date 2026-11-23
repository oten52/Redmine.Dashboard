# frozen_string_literal: true

class RedmineDashboardController < ApplicationController
  before_action :find_dashboard_project
  before_action :require_dashboard_access
  helper_method :dashboard_issue_path, :dashboard_query_groups

  def show
    @queries = load_queries
    @query = find_query
    return unless @query

    @query.project = @project if @project
    if @query.valid?
      @report = RedmineDashboard::Report.new(@query)
      @report.load
    end
  end

  private

  def find_dashboard_project
    return true if params[:project_id].blank?

    @project = Project.find(params[:project_id])
    true
  rescue ActiveRecord::RecordNotFound
    render_404
    false
  end

  def require_dashboard_access
    options = @project ? {} : {:global => true}
    unless User.current.allowed_to?(:view_issues, @project, options)
      deny_access
      return false
    end
    true
  end

  def load_queries
    scope = IssueQuery.visible.order("#{IssueQuery.table_name}.name ASC")
    if @project
      scope = scope.where(
        "#{IssueQuery.table_name}.project_id IS NULL OR #{IssueQuery.table_name}.project_id = ?",
        @project.id
      )
    end
    scope.to_a.reject { |query| query.name.to_s == '_' }
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[Dashboard] #{e.class}: #{e.message}")
    @queries_error = true
    []
  end

  def find_query
    chosen = query_param
    if params.key?(:query_id)
      if chosen
        session[session_key] = chosen
      else
        session.delete(session_key)
      end
    end

    query_id = chosen || session[session_key].to_s
    return nil unless query_id.match?(/\A\d+\z/)

    found = @queries.detect { |query| query.id.to_s == query_id }
    if found.nil?
      session.delete(session_key)
      @missing_query = chosen.present?
    end
    found
  end

  def query_param
    raw = params[:query_id]
    raw = raw.first if raw.is_a?(Array)
    value = raw.to_s
    value if value.match?(/\A\d+\z/)
  end

  def session_key
    @project ? "redmine_dashboard_query_#{@project.id}" : 'redmine_dashboard_query'
  end

  def dashboard_query_groups
    buckets = {}
    @queries.each do |query|
      key = query.project ? query.project.name.to_s : ''
      buckets[key] ||= []
      buckets[key] << [query.name, query.id]
    end
    groups = []
    global = buckets.delete('')
    groups << [l(:redmine_dashboard_global), global.sort_by { |pair| pair.first.to_s.downcase }] if global && global.any?
    buckets.keys.sort.each do |name|
      groups << [name, buckets[name].sort_by { |pair| pair.first.to_s.downcase }]
    end
    groups
  end

  def dashboard_issue_path
    options = {:controller => 'issues', :action => 'index', :query_id => @query.id, :only_path => true}
    options[:project_id] = @query.project if @query.project
    url_for(options)
  end
end
