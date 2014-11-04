module Gitlab
  module Git
    class Compare
      TIME_OUT_TIME = 30
      attr_reader :commits, :diffs, :same, :timeout_diffs, :timeout_commits, :head, :base

      def initialize(repository, base, head)
        @commits, @diffs = [], []
        @same = false
        @repository = repository
        @timeout_diffs = false
        @timeout_commits = false

        return unless base && head

        @base = Gitlab::Git::Commit.find(repository, base.try(:strip))
        @head = Gitlab::Git::Commit.find(repository, head.try(:strip))

        return unless @base && @head

        if @base.id == @head.id
          @same = true
          return
        end
      end

      def commits
        return [] if @same

        if @commits.empty? && @timeout_commits == false
          begin
            Timeout.timeout(TIME_OUT_TIME) do 
              @commits = Gitlab::Git::Commit.between(repository, @base.id, @head.id)
            end
          rescue Timeout::Error => ex
            @commits = []
            @timeout_commits = true
          end
        end
        @commits
      end

      def diffs(paths = nil)
        return [] if @same

        # Try to collect diff only if diffs is empty
        # Otherwise return cached version
        if @diffs.empty? && @timeout_diffs == false
          begin
            Timeout.timeout(TIME_OUT_TIME) do
              @diffs = Gitlab::Git::Diff.between(@repository, @head.id, @base.id, *paths)
            end
          rescue Timeout::Error => ex
            @diffs = []
            @timeout_diffs = true
          end
        end

        @diffs
      end

      # Check if diff is empty because it is actually empty
      # and not because its impossible to get it
      def empty_diff?
        diffs.empty? && timeout == false
      end
    end
  end
end
