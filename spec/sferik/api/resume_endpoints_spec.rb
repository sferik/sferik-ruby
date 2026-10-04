# frozen_string_literal: true

RSpec.describe Sferik::API::ResumeEndpoints do
  let(:client) { Sferik::Client.new }

  describe "#resume" do
    before { stub_get("/resume", "resume.json") }

    it "returns the basics" do
      expect(client.resume.basics).to have_attributes(name: "Erik Berlin", former_name: "Erik Michaels-Ober", label: String, email: "sferik@gmail.com",
        url: "https://sferik.net", summary: String)
    end

    it "returns where Erik lives" do
      expect(client.resume.basics.location).to have_attributes(city: "San Francisco", region: "California", country_code: "US")
    end

    it "returns profiles elsewhere" do
      expect(client.resume.basics.profiles.first).to have_attributes(network: "GitHub", username: "sferik", url: "https://github.com/sferik")
    end

    it "returns work, newest first, with partial dates as dates" do
      expect(client.resume.work.first).to have_attributes(position: "Founder", name: String, start_date: Date.new(2023, 1, 1), end_date: nil)
    end

    it "returns highlights of work" do
      expect(client.resume.work[1].highlights).to all(be_a(String))
    end

    it "returns volunteer roles, with a year alone as the first day of that year" do
      expect(client.resume.volunteer.last).to have_attributes(position: "Coach and mentor", organization: String, start_date: Date.new(2013, 1, 1),
        end_date: Date.new(2013, 1, 1), summary: nil, url: nil)
    end

    it "returns schools" do
      expect(client.resume.education.first).to have_attributes(institution: "Carnegie Mellon University", location: "Pittsburgh", start_date: Date,
        end_date: Date, highlights: ["Student Body President"], courses: [])
    end

    it "returns awards" do
      expect(client.resume.awards.first).to have_attributes(title: "Ruby Hero Award", date: Date.new(2014, 4, 22), awarder: String, summary: String)
    end

    it "returns patents" do
      expect(client.resume.patents.map(&:number)).to eq(%w[US20110153423A1 US20110153414A1])
    end

    it "returns the details of patents" do
      expect(client.resume.patents.first).to have_attributes(title: String, date: Date.new(2011, 6, 23), url: %r{\Ahttps://patents.google.com/})
    end

    it "returns open source work, skills, and speaking" do
      resume = client.resume

      expect([resume.projects.first.name, resume.projects.first.description, resume.skills.first.name, resume.skills.first.keywords.first,
        resume.speaking.summary]).to match(["RubyGems.org", String, "Languages", "Ruby", /\ASpoke at/])
    end

    it "returns what the resume says about itself" do
      expect(client.resume.meta).to have_attributes(canonical: "https://sferik.net/resume", version: "v1.0.0", last_modified: Date.new(2026, 10, 1))
    end
  end

  describe "#resume_latex" do
    it "asks for LaTeX" do
      stub_request(:get, "https://sferik.net/resume").with(headers: {"Accept" => "application/x-latex"}).to_return(body: "\\documentclass{article}")

      expect(client.resume_latex).to start_with("\\documentclass")
    end
  end

  describe "#resume_pdf" do
    it "asks for a PDF" do
      stub_request(:get, "https://sferik.net/resume").with(headers: {"Accept" => "application/pdf"}).to_return(body: "%PDF-1.4\n")

      expect(client.resume_pdf).to start_with("%PDF-1.4")
    end
  end
end
