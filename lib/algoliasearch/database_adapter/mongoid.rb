module DatabaseAdapter
  module Mongoid
    extend self

    # work-around mongoid 2.4's unscoped method, not accepting a block
    def get_default_attributes(object)
      object.attributes
    end

    def get_attributes(attributes, object)
      DatabaseAdapter.attributes_to_hash(attributes, object)
    end

    def find_in_batches(klass, batch_size, &block)
      items = []
      klass.all.each do |item|
        items << item
        if items.length % batch_size == 0
          yield items
          items = []
        end
      end
      yield items unless items.empty?
    end

    def prepare_for_auto_index(klass)
      klass.class_eval do
        after_validation :algolia_mark_must_reindex if respond_to?(:after_validation)
        before_save :algolia_mark_for_auto_indexing if respond_to?(:before_save)
        if respond_to?(:after_commit)
          after_commit :algolia_perform_index_tasks
        elsif respond_to?(:after_save)
          after_save :algolia_perform_index_tasks
        end
      end
    end

    def prepare_for_auto_remove(klass)
      klass.class_eval do
        after_destroy { |searchable| searchable.algolia_enqueue_remove_from_index!(algolia_synchronous?) } if respond_to?(:after_destroy)
      end
    end

    def prepare_for_synchronous(klass)
      klass.class_eval do
        after_validation :algolia_mark_synchronous if respond_to?(:after_validation)
      end
    end

    def mark_must_reindex(object)
      object.new_record? || object.class.algolia_must_reindex?(object)
    end
  end
end
