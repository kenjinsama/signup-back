require 'rails_helper'

RSpec.describe Enrollment, type: :model do
  let(:enrollment) { FactoryGirl.create(:enrollment) }
  after do
    DocumentUploader.new(Enrollment, :attachment).remove!
  end

  it 'can have messages attached to it' do
    expect do
      enrollment.messages.create(user: FactoryGirl.create(:user), content: 'test')
    end.to change { enrollment.messages.count }
  end

  Enrollment::DOCUMENT_TYPES.each do |document_type|
    describe document_type do
      it 'can have document' do
        expect do
          enrollment.documents.create(
            type: document_type,
            attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
          )
        end.to(change { enrollment.documents.count })
      end

      it 'can only have a document' do
        enrollment.documents.create(
          type: document_type,
          attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
        )

        expect do
          enrollment.documents.create(
            type: document_type,
            attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
          )
        end.not_to(change { enrollment.documents.count })
      end

      it 'overwrites the document' do
        enrollment.documents.create(
          type: document_type,
          attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
        )

        document = enrollment.documents.create(
          type: document_type,
          attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
        )

        expect(enrollment.documents.last).to eq(document)
      end
    end
  end

  describe 'workflow' do
    it 'should start on initial state' do
      expect(enrollment.state).to eq('filled_application')
    end

    it 'is on completed_application state if all documents uploaded' do
      Enrollment::DOCUMENT_TYPES.each do |document_type|
        enrollment.documents.create(
          type: document_type,
          attachment: Rack::Test::UploadedFile.new(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
        )
      end

      expect(enrollment.state).to eq('waiting_for_approval')
    end

    describe 'the enrollment is on waiting_for_approval state' do
      let(:enrollment) { FactoryGirl.create(:enrollment, state: 'waiting_for_approval') }

      it 'can be refused and sent back to filled_application' do
        enrollment.refuse_application!

        expect(enrollment.state).to eq('filled_application')
      end

      it 'can be approved application and sent to application_approved state' do
        enrollment.approve_application!

        expect(enrollment.state).to eq('application_approved')
      end
    end

    describe 'the enrollment is on application_approved state' do
      let(:enrollment) { FactoryGirl.create(:enrollment, state: 'application_approved') }

      it 'can sign convention and send to application_ready state' do
        enrollment.sign_convention!

        expect(enrollment.state).to eq('application_ready')
      end
    end

    describe 'the enrollment is on application_ready state' do
      let(:enrollment) { FactoryGirl.create(:enrollment, state: 'application_ready') }

      it 'can deploy and send to deployed state' do
        enrollment.deploy!

        expect(enrollment.state).to eq('deployed')
      end
    end
  end
end