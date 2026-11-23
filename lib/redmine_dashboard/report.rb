# frozen_string_literal: true

module RedmineDashboard
  class Report
    include Redmine::I18n

    SAMPLE_LIMIT = 2000
    COLUMN_LIMIT = 10
    ROW_LIMIT = 30
    SKIPPED_COLUMNS = %w[id subject description last_notes attachments relations parent].freeze
    DEFAULT_COLUMNS = %w[status priority tracker assigned_to author category fixed_version project].freeze

    attr_reader :total, :open_count, :closed_count, :unassigned_count, :latest_update,
                :sections, :error, :column_error, :sampled

    def initialize(query, column_names = nil)
      @query = query
      @column_names = column_names
      @total = 0
      @open_count = 0
      @closed_count = 0
      @unassigned_count = 0
      @latest_update = nil
      @sections = []
      @error = nil
      @column_error = nil
      @sampled = false
    end

    def load
      @total = count_rows(relation).to_i
      return self if @error || @total.zero?

      @closed_count = closed_rows.to_i
      @open_count = [@total - @closed_count, 0].max
      @unassigned_count = grouped("#{Issue.table_name}.assigned_to_id")[nil].to_i
      return self if @error

      @latest_update = latest_timestamp
      @sections = build_sections
      self
    end

    def available_columns
      @available_columns ||= begin
        columns = @query.respond_to?(:columns) ? @query.columns : []
        columns.reject {|column| SKIPPED_COLUMNS.include?(column.name.to_s)}
      rescue StandardError
        []
      end
    end

    def selected_columns
      @selected_columns ||= begin
        by_name = available_columns.index_by {|column| column.name.to_s}
        names = @column_names.nil? ? default_names : Array(@column_names)
        names.map {|name| by_name[name.to_s]}.compact.first(COLUMN_LIMIT)
      end
    end

    def selected_names
      selected_columns.map {|column| column.name.to_s}
    end

    def caption_for(column)
      column_title(column)
    end

    private

    def default_names
      preferred = available_columns.select {|column| preferred_column?(column)}
      preferred = available_columns if preferred.empty?
      preferred.map {|column| column.name.to_s}.first(COLUMN_LIMIT)
    end

    def preferred_column?(column)
      name = column.name.to_s
      return false if %w[updated_on created_on closed_on start_date due_date done_ratio estimated_hours].include?(name)
      return true if name.start_with?('cf_', 'relc_', 'rel_')
      return true if DEFAULT_COLUMNS.include?(name)

      column.respond_to?(:groupable?) && column.groupable?
    end

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

    def build_sections
      columns = selected_columns
      return [] if columns.empty? || @error

      issues = sample_issues
      return [] if @error || @column_error

      preload_related(issues, columns)
      @sampled = @total > SAMPLE_LIMIT
      columns.map {|column| section_for(column, issues)}
    end

    def sample_issues
      scope = relation.reorder(nil).order("#{Issue.table_name}.updated_on DESC")
      scope = scope.limit(SAMPLE_LIMIT) if @total > SAMPLE_LIMIT
      scope.preload(
        :status, :priority, :tracker, :assigned_to, :author,
        :category, :fixed_version, :project, {:custom_values => :custom_field}
      ).to_a
    rescue StandardError => e
      log_error(e)
      @column_error = :redmine_dashboard_columns_failed
      []
    end

    def preload_related(issues, columns)
      return if issues.empty?
      return unless columns.any? {|column| column.class.name.to_s.include?('RelatedColumn')}

      picker = 'RedmineIliskiliTask::Picker'.safe_constantize
      picker.preload(issues) if picker && picker.respond_to?(:preload)
    rescue StandardError => e
      Rails.logger.error("[Dashboard] #{e.class}: #{e.message}") if defined?(Rails)
    end

    def section_for(column, issues)
      counts = Hash.new(0)
      records = {}
      issues.each do |issue|
        label, record = present(column, issue)
        counts[label] += 1
        records[label] = record if record && records[label].nil?
      end
      rows = counts.map do |label, count|
        {
          :label => label,
          :count => count,
          :blank => label.nil?,
          :record => records[label]
        }
      end
      pack(column, rows)
    end

    def present(column, issue)
      raw = column.value(issue)
      [text_of(column, raw), avatar_for(raw)]
    rescue StandardError
      [nil, nil]
    end

    def text_of(column, raw)
      return "#{raw.to_i}%" if column.name.to_s == 'done_ratio' && raw.is_a?(Numeric)

      case raw
      when nil, ''
        nil
      when Array
        parts = raw.map {|item| text_of(column, item)}.reject(&:blank?)
        parts.empty? ? nil : clip(parts.join(', '))
      when true
        l(:general_text_Yes)
      when false
        l(:general_text_No)
      when Date
        format_date(raw)
      when Time, ActiveSupport::TimeWithZone
        format_date(raw.to_date)
      when Numeric
        raw.to_s
      else
        raw.respond_to?(:name) ? clip(raw.name) : clip(raw)
      end
    end

    def avatar_for(raw)
      return raw if raw.is_a?(User)
      return nil unless raw.is_a?(Array)

      users = raw.select {|item| item.is_a?(User)}
      users.first if users.size == 1
    end

    def clip(text)
      value = text.to_s.gsub(/\s+/, ' ').strip
      return nil if value.blank?
      return value if value.length <= 80

      "#{value[0, 80]}…"
    end

    def pack(column, rows)
      rows = rows.sort_by {|row| [-row[:count], row[:label].to_s]}
      if rows.size > ROW_LIMIT
        rest = rows.drop(ROW_LIMIT)
        rows = rows.first(ROW_LIMIT)
        rows << {
          :label => nil,
          :count => rest.sum {|row| row[:count]},
          :record => nil,
          :blank => false,
          :more => rest.size
        }
      end
      {
        :title => column_title(column),
        :tone => column.name.to_s.each_byte.sum % 7,
        :blank_label => column.name.to_s == 'assigned_to' ? :redmine_dashboard_unassigned : :redmine_dashboard_empty_value,
        :rows => rows,
        :max => rows.map {|row| row[:count]}.max.to_i
      }
    end

    def column_title(column)
      column.caption.to_s
    rescue StandardError
      column.name.to_s
    end

    def remember(error)
      log_error(error)
      @error = :redmine_dashboard_query_failed
    end

    def log_error(error)
      message = error.message.to_s.encode('UTF-8', :invalid => :replace, :undef => :replace)
      message = message.byteslice(0, 2000).to_s
      Rails.logger.error("[Dashboard] #{error.class}: #{message}") if defined?(Rails)
    rescue StandardError
      nil
    end
  end
end
