module Searchkick
  class BulkReindexJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name:, record_ids: nil, index_name: nil, method_name: nil, batch_id: nil, min_id: nil, max_id: nil)
      klass = class_name.constantize
      index = index_name ? Searchkick::Index.new(index_name, **klass.searchkick_options) : klass.searchkick_index
      record_ids ||= min_id..max_id
      RecordIndexer.new(index).reindex_records(
        Searchkick.load_records(klass, record_ids),
        method_name: method_name,
        mode: :inline
      )
      Searchkick.with_redis { |r| r.srem(index.send(:bulk_indexer).send(:batches_key), batch_id) } if batch_id
    end
  end
end
