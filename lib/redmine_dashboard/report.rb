# frozen_string_literal: true

module RedmineDashboard
  class Report
    attr_reader :total, :open_count, :closed_count, :unassigned_count, :latest_update, :sections, :error

    def initialize(query)
      @query = query
      @total = 0
      @open_count = 0
      @closed_count = 0
      @unassigned_count = 0
      @latest_update = nil
      @sections = []
      @error = nil
    end

    def load
      @total = count_rows(relation).to_i
      return self if @error || @total.zero?

      @closed_count = closed_rows.to_i
      @open_count = [@total - @closed_count, 0].max
      assignee_rows = grouped("#{Issue.table_name}.assigned_to_id")
      @unassigned_count = assignee_rows[nil].to_i
      return self if @error

      @latest_update = latest_timestamp
      @sections = build_sections(assignee_rows)
      self
    end

    private

    def relation
      @relation ||= begin
        if @query.respond_to?(:base_scope, true)
          @query.send(:base_scope)
        else
          scope = Issue.visible.joins(:status, :project)
          sql = @query.statement
          sql.present? ? scope.where(sql) : scope
        end
      end
    end

    def counted(scope)
      scope.reorder(nil).distinct.count(:id)
    end

    def count_rows(scope)
      counted(scope)
    rescue ActiveRecord::StatementInvalid => e
      remember(e)
      0
    end

    def grouped(column)
      return {} if @error

      counted(relation.group(column))
    rescue ActiveRecord::StatementInvalid => e
      remember(e)
      {}
    end

    def closed_rows
      raw = grouped("#{IssueStatus.table_name}.is_closed")
      raw.inject(0) do |sum, (key, count)|
        closed = key == true || key.to_s == '1' || key.to_s == 't' || key.to_s == 'true'
        closed ? sum + count.to_i : sum
      end
    end

    def latest_timestamp
      return nil if @error

      relation.reorder(nil).maximum(Issue.arel_table[:updated_on])
    rescue ActiveRecord::StatementInvalid => e
      remember(e)
      nil
    end

    def build_sections(assignee_rows)
      return [] if @error || @total.zero?

      list = []
      list << dimension(:priority, :priority_id, IssuePriority, :position)
      list << people(:assignee, assignee_rows, Principal)
      list << dimension(:status, :status_id, IssueStatus, :position)
      list << dimension(:tracker, :tracker_id, Tracker, :position)
      list << dimension(:version, :fixed_version_id, Version, :count, :require_value => true)
      list << people(:author, grouped("#{Issue.table_name}.author_id"), User)
      list << projects
      list.compact
    end

    def dimension(key, column, model, order, options = {})
      raw = grouped("#{Issue.table_name}.#{column}")
      return nil if raw.blank?
      return nil if options[:require_value] && raw.keys.compact.empty?

      rows = named_rows(raw, model)
      pack(key, rows, order, nil)
    end

    def people(key, raw, model)
      return nil if raw.blank?

      rows = named_rows(raw, model)
      pack(key, rows, :count, 40)
    end

    def projects
      raw = grouped("#{Issue.table_name}.project_id")
      return nil if raw.keys.compact.size < 2

      pack(:project, named_rows(raw, Project), :count, 40)
    end

    def named_rows(raw, model)
      ids = raw.keys.compact.map(&:to_i)
      records = model.where(:id => ids).index_by(&:id)
      raw.map do |id, count|
        record = id.nil? ? nil : records[id.to_i]
        {
          :label => record ? record.name : (id.nil? ? nil : "##{id}"),
          :count => count.to_i,
          :record => record,
          :blank => id.nil?,
          :position => record.respond_to?(:position) ? record.position.to_i : 9999
        }
      end
    end

    def pack(key, rows, order, cap)
      rows = if order == :position
               rows.sort_by {|row| [row[:position], row[:label].to_s]}
             else
               rows.sort_by {|row| [-row[:count], row[:label].to_s]}
             end
      if cap && rows.size > cap
        rest = rows.drop(cap)
        rows = rows.first(cap)
        rows << {:label => nil, :count => rest.sum {|row| row[:count]}, :record => nil, :blank => false, :more => rest.size}
      end
      max = rows.map {|row| row[:count]}.max.to_i
      {:key => key, :rows => rows, :max => max}
    end

    def remember(error)
      message = error.message.to_s.encode('UTF-8', :invalid => :replace, :undef => :replace)
      message = message.byteslice(0, 2000).to_s
      Rails.logger.error("[Dashboard] #{error.class}: #{message}") if defined?(Rails)
    rescue StandardError
      nil
    ensure
      @error = :redmine_dashboard_query_failed
    end
  end
end
