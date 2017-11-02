RSpec.describe Hyrax::Actors::CollectionsMembershipActor do
  let(:user) { create(:user) }
  let(:ability) { ::Ability.new(user) }
  let(:curation_concern) { create_for_repository(:work) }
  let(:attributes) { {} }
  let(:terminator) { Hyrax::Actors::Terminator.new }
  let(:change_set) { GenericWorkChangeSet.new(curation_concern) }
  let(:change_set_persister) { Hyrax::ChangeSetPersister.new(metadata_adapter: Valkyrie::MetadataAdapter.find(:indexing_persister), storage_adapter: Valkyrie.config.storage_adapter) }
  let(:env) { Hyrax::Actors::Environment.new(change_set, change_set_persister, ability, attributes) }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
      middleware.use Hyrax::Actors::GenericWorkActor
    end
    stack.build(terminator)
  end

  describe 'the next actor' do
    let(:attributes) do
      { member_of_collection_ids: ['123'], title: ['test'] }
    end

    before do
      allow(Collection).to receive(:find).with(['123'])
      allow(curation_concern).to receive(:member_of_collection_ids=)
    end

    it 'does not receive the member_of_collection_ids' do
      expect(terminator).to receive(:create).with(Hyrax::Actors::Environment) do |k|
        expect(k.attributes).to eq("title" => ["test"])
      end
      subject.create(env)
    end
  end

  describe 'create' do
    let(:collection) { create_for_repository(:collection) }
    let(:attributes) do
      { member_of_collection_ids: [collection.id], title: ['test'] }
    end

    it 'adds it to the collection' do
      expect(subject.create(env)).to be true
      reloaded = Hyrax::Queries.find_by(id: collection.id)
      expect(reloaded.member_object_ids).to eq [curation_concern.id]
    end

    describe "when work is in user's own collection" do
      let(:collection) { create_for_repository(:collection, user: user, title: ['A good title']) }
      let(:attributes) { { member_of_collection_ids: [] } }
      let(:env_initial) do
        Hyrax::Actors::Environment.new(change_set, change_set_persister, ability, member_of_collection_ids: [collection.id], title: ['test'])
      end

      before do
        subject.create(env_initial)
      end

      it "removes the work from that collection" do
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collection_ids).to eq []
      end
    end

    describe "when work is in another user's collection" do
      let(:other_user) { create(:user) }
      let(:collection) { create_for_repository(:collection, user: other_user, title: ['A good title']) }

      it "doesn't remove the work from that collection" do
        subject.create(env)
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collection_ids).to eq [collection.id]
      end
    end
  end
end
