module Searchkick
  class RecordIndexer
    attr_reader :index

    def initialize(index)
      @index = index
    end

    def reindex_records(records, mode: nil, method_name: nil, refresh: false)
      unless [:inline, true, nil, :async, :queue].include?(mode)
        raise ArgumentError, "Invalid value for mode"
      end

      # check afterwards for bulk
      mode ||= Searchkick.callbacks_value || index.options[:callbacks] || true

      case mode
      when :queue
        if method_name
          raise Searchkick::Error, "Partial reindex not supported with queue option"
        end

        record_ids =
          records.map do |record|
            # always pass routing in case record is deleted
            # before the queue job runs
            if record.respond_to?(:search_routing)
              routing = record.search_routing
            end

            # escape pipe with double pipe
            value = queue_escape(record.id.to_s)
            value = "#{value}|#{queue_escape(routing)}" if routing
            value
          end

        index.reindex_queue.push(*record_ids)
      when :async
        unless defined?(ActiveJob)
          raise Searchkick::Error, "Active Job not found"
        end

        # TODO use single job
        records.each do |record|
          # always pass routing in case record is deleted
          # before the async job runs
          if record.respond_to?(:search_routing)
            routing = record.search_routing
          end

          Searchkick::ReindexV2Job.perform_later(
            record.class.name,
            record.id.to_s,
            method_name ? method_name.to_s : nil,
            routing: routing
          )
        end
      else # bulk, inline/true/nil
        relation = relation.search_import if relation.respond_to?(:search_import)

        delete_records, index_records = records.partition { |r| r.destroyed? || !r.persisted? || !r.should_index? }

        # TODO use
        # Searchkick.callbacks(:bulk)
        # and
        # index.bulk_delete(delete_records)
        delete_records.each do |record|
          begin
            index.remove(record)
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
            # do nothing
          end
        end

        if method_name
          index.bulk_update(index_records, method_name)
        else
          index.bulk_index(index_records)
        end

        index.refresh if refresh
      end
    end

    private

    def queue_escape(value)
      value.gsub("|", "||")
    end
  end
end
