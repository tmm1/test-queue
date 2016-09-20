module TestQueue
  # This class provides an abstraction over the various test frameworks we
  # support. The framework-specific subclasses are defined in the various
  # test_queue/runner/* files.
  class TestFramework
    # Return all file paths to load test suites from.
    #
    # An example implementation might just return files passed on the command
    # line, or defer to the underlying test framework to determine which files
    # to load.
    #
    # Returns an Enumerable of String file paths.
    def all_suite_files
      raise NotImplementedError
    end

    # Load all suites from the specified file path.
    #
    # path - String file path to load suites from
    #
    # Returns an Enumerable of tuples containing:
    #   suite_name   - String that uniquely identifies this suite
    #   suite        - Framework-specific object that can be used to actually
    #                  run the suite
    def suites_from_file(path)
      raise NotImplementedError
    end
  end
end
