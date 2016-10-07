module Agents

  class Mysql2AgentConnection < ActiveRecord::Base
    def self.abstract_class?
      true # So it gets its own connection
    end
  end

  class Mysql2Agent < Agent
    
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        Run custom mysql query

        `connection_url`:

         – from credentials:

            {% credential mysql_connection %}

        – from string:

            mysql2://user:pass@localhost/database

        `sql` – custom sql query

            select id, title from mytable where ... order by limit 30

      MD
    end

    event_description <<-MD
      Events look like result's fields
    MD

    def default_options
      {
          'connection_url' => 'mysql2://user:pass@localhost/database',
          'sql' => 'select * from table_name order by id desc limit 30',
          'expected_receive_period_in_days' => '1'
      }
    end

    form_configurable :connection_url
    form_configurable :sql, type: :text
    form_configurable :expected_receive_period_in_days

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        handle(interpolated(event), event)
      end
    end

    def check
      handle(interpolated)
    end

    private

    def handle(opts, event = nil)

      connection_url = opts["connection_url"]
      sql = opts["sql"]

      begin
        conn = Mysql2AgentConnection.establish_connection(connection_url).connection
      rescue => error
        log("establish_connection err #{error.inspect}")
        return
      end

      results = conn.exec_query(sql)
      if results.present?
         results.each do |row|
           created_event = create_event payload: row
           log("Ran '#{sql}' ", outbound_event: created_event, inbound_event: event)
         end
      else
        log("Ran '#{sql}' return nil", inbound_event: event)
      end

    end

  end
end