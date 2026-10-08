# frozen_string_literal: true

require_relative "../resume"

module Sferik
  module API
    # The endpoints for the resume, as data, LaTeX, or a PDF
    # @api public
    module ResumeEndpoints
      # Returns the resume as a JSON Resume document
      #
      # @api public
      # @return [Resume]
      # @example
      #   Sferik.resume.work.first.position
      def resume
        json("/resume") { |attributes| Resume.new(attributes) }
      end

      # Returns the resume as a LaTeX document, ready for pdflatex or tectonic
      #
      # @api public
      # @return [String] the LaTeX source
      # @example
      #   File.write("resume.tex", Sferik.resume_latex)
      def resume_latex
        get("/resume", accept: "application/x-latex")
      end

      # Returns the resume as a two-page PDF
      #
      # @api public
      # @return [String] the PDF, as binary
      # @example
      #   File.binwrite("resume.pdf", Sferik.resume_pdf)
      def resume_pdf
        get("/resume", accept: "application/pdf")
      end
    end
  end
end
