require 'spec_helper'

describe CurationConcerns::FileSetAuditService do
  let(:f)       { create(:file_set, content: File.open(fixture_file_path('world.png'))) }
  let(:service) { described_class.new(f) }

  describe '#audit' do
    context 'when a file has two versions' do
      before do
        CurationConcerns::VersioningService.create(f.original_file) # create a second version -- the factory creates the first version when it attaches +content+
      end
      subject { service.audit[f.original_file.id] }
      specify 'returns two log results' do
        expect(subject.length).to eq(2)
      end
    end
  end

  describe '#audit_file' do
    subject { service.send(:audit_file, f.original_file) }
    specify 'returns a single result' do
      expect(subject.length).to eq(1)
    end
  end

  describe '#audit_file_version' do
    subject { service.send(:audit_file_version, f.original_file.id, f.original_file.uri) }
    specify 'returns a single ChecksumAuditLog for the given file' do
      expect(subject).to be_kind_of ChecksumAuditLog
      expect(subject.file_set_id).to eq(f.id)
      expect(subject.version).to eq(f.original_file.uri)
    end
  end

  describe '#audit_stat' do
    subject { service.send(:audit_stat, f.original_file) }
    context 'when no audits have been run' do
      it 'reports that audits have not been run' do
        expect(subject).to eq 'Audits have not yet been run on this file.'
      end
    end

    context 'when no audit is pasing' do
      before do
        CurationConcerns::VersioningService.create(f.original_file)
        ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.uri, file_id: 'original_file')
      end

      it 'reports that audits have not been run' do
        expect(subject).to eq 'Some audits have not been run, but the ones run were passing.'
      end
    end
  end

  describe '#human_readable_audit_status' do
    before do
      CurationConcerns::VersioningService.create(f.original_file)
      ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.uri, file_id: 'original_file')
    end
    subject { service.human_readable_audit_status }
    it { is_expected.to eq 'Some audits have not been run, but the ones run were passing.' }
  end

  describe '#stat_to_string' do
    subject { service.send(:stat_to_string, val) }
    context 'when audit_stat is 0' do
      let(:val) { 0 }
      it { is_expected.to eq 'failing' }
    end

    context 'when audit_stat is 1' do
      let(:val) { 1 }
      it { is_expected.to eq 'passing' }
    end

    context 'when audit_stat is something else' do
      let(:val) { 'something else' }
      it "fails" do
        expect { subject }.to raise_error ArgumentError, "Unknown status `something else'"
      end
    end
  end
end
