require 'spec_helper'

describe Discussion, model: true do
  subject { described_class.new([first_note, second_note, third_note]) }

  let(:first_note) { create(:diff_note_on_merge_request) }
  let(:second_note) { create(:diff_note_on_merge_request) }
  let(:third_note) { create(:diff_note_on_merge_request) }

  describe "#resolvable?" do
    context "when a diff discussion" do
      before do
        allow(subject).to receive(:diff_discussion?).and_return(true)
      end

      context "when all notes are unresolvable" do
        before do
          allow(first_note).to receive(:resolvable?).and_return(false)
          allow(second_note).to receive(:resolvable?).and_return(false)
          allow(third_note).to receive(:resolvable?).and_return(false)
        end

        it "returns false" do
          expect(subject.resolvable?).to be false
        end
      end

      context "when some notes are unresolvable and some notes are resolvable" do
        before do
          allow(first_note).to receive(:resolvable?).and_return(true)
          allow(second_note).to receive(:resolvable?).and_return(false)
          allow(third_note).to receive(:resolvable?).and_return(true)
        end

        it "returns true" do
          expect(subject.resolvable?).to be true
        end
      end

      context "when all notes are resolvable" do
        before do
          allow(first_note).to receive(:resolvable?).and_return(true)
          allow(second_note).to receive(:resolvable?).and_return(true)
          allow(third_note).to receive(:resolvable?).and_return(true)
        end

        it "returns true" do
          expect(subject.resolvable?).to be true
        end
      end
    end

    context "when not a diff discussion" do
      before do
        allow(subject).to receive(:diff_discussion?).and_return(false)
      end

      it "returns false" do
        expect(subject.resolvable?).to be false
      end
    end
  end

  describe "#resolved?" do
    context "when not resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(false)
      end

      it "returns false" do
        expect(subject.resolved?).to be false
      end
    end

    context "when resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(true)

        allow(first_note).to receive(:resolvable?).and_return(true)
        allow(second_note).to receive(:resolvable?).and_return(false)
        allow(third_note).to receive(:resolvable?).and_return(true)
      end

      context "when all resolvable notes are resolved" do
        before do
          allow(first_note).to receive(:resolved?).and_return(true)
          allow(third_note).to receive(:resolved?).and_return(true)
        end

        it "returns true" do
          expect(subject.resolved?).to be true
        end
      end

      context "when some resolvable notes are not resolved" do
        before do
          allow(first_note).to receive(:resolved?).and_return(true)
          allow(third_note).to receive(:resolved?).and_return(false)
        end

        it "returns false" do
          expect(subject.resolved?).to be false
        end
      end
    end
  end

  describe "#to_be_resolved?" do
    context "when not resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(false)
      end

      it "returns false" do
        expect(subject.to_be_resolved?).to be false
      end
    end

    context "when resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(true)

        allow(first_note).to receive(:resolvable?).and_return(true)
        allow(second_note).to receive(:resolvable?).and_return(false)
        allow(third_note).to receive(:resolvable?).and_return(true)
      end

      context "when all resolvable notes are resolved" do
        before do
          allow(first_note).to receive(:resolved?).and_return(true)
          allow(third_note).to receive(:resolved?).and_return(true)
        end

        it "returns false" do
          expect(subject.to_be_resolved?).to be false
        end
      end

      context "when some resolvable notes are not resolved" do
        before do
          allow(first_note).to receive(:resolved?).and_return(true)
          allow(third_note).to receive(:resolved?).and_return(false)
        end

        it "returns true" do
          expect(subject.to_be_resolved?).to be true
        end
      end
    end
  end

  describe "#can_resolve?" do
    let(:current_user) { create(:user) }

    context "when not resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(false)
      end

      it "returns false" do
        expect(subject.can_resolve?(current_user)).to be false
      end
    end

    context "when resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(true)
      end

      context "when not signed in" do
        let(:current_user) { nil }

        it "returns false" do
          expect(subject.can_resolve?(current_user)).to be false
        end
      end

      context "when signed in" do
        context "when the signed in user is the noteable author" do
          before do
            subject.noteable.author = current_user
          end

          it "returns true" do
            expect(subject.can_resolve?(current_user)).to be true
          end
        end

        context "when the signed in user can push to the project" do
          before do
            subject.project.team << [current_user, :master]
          end

          it "returns true" do
            expect(subject.can_resolve?(current_user)).to be true
          end
        end

        context "when the signed in user is a random user" do
          it "returns false" do
            expect(subject.can_resolve?(current_user)).to be false
          end
        end
      end
    end
  end

  describe "#resolve!" do
    let(:current_user) { create(:user) }

    context "when not resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(false)
      end

      it "returns nil" do
        expect(subject.resolve!(current_user)).to be_nil
      end

      it "doesn't set resolved_at" do
        subject.resolve!(current_user)

        expect(subject.resolved_at).to be_nil
      end

      it "doesn't set resolved_by" do
        subject.resolve!(current_user)

        expect(subject.resolved_by).to be_nil
      end

      it "doesn't mark as resolved" do
        subject.resolve!(current_user)

        expect(subject.resolved?).to be false
      end
    end

    context "when resolvable" do
      let(:user) { create(:user) }

      before do
        allow(subject).to receive(:resolvable?).and_return(true)

        allow(first_note).to receive(:resolvable?).and_return(true)
        allow(second_note).to receive(:resolvable?).and_return(false)
        allow(third_note).to receive(:resolvable?).and_return(true)
      end

      context "when all resolvable notes are resolved" do
        before do
          first_note.resolve!(user)
          third_note.resolve!(user)
        end

        it "calls resolve! on every resolvable note" do
          expect(first_note).to receive(:resolve!).with(current_user)
          expect(second_note).not_to receive(:resolve!)
          expect(third_note).to receive(:resolve!).with(current_user)

          subject.resolve!(current_user)
        end

        it "doesn't change resolved_at on the resolved notes" do
          expect(first_note.resolved_at).not_to be_nil
          expect(third_note.resolved_at).not_to be_nil

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved_at }
          expect { subject.resolve!(current_user) }.not_to change { third_note.resolved_at }
        end

        it "doesn't change resolved_by on the resolved notes" do
          expect(first_note.resolved_by).to eq(user)
          expect(third_note.resolved_by).to eq(user)

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved_by }
          expect { subject.resolve!(current_user) }.not_to change { third_note.resolved_by }
        end

        it "doesn't change the resolved state on the resolved notes" do
          expect(first_note.resolved?).to be true
          expect(third_note.resolved?).to be true

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved? }
          expect { subject.resolve!(current_user) }.not_to change { third_note.resolved? }
        end

        it "doesn't change resolved_at" do
          expect(subject.resolved_at).not_to be_nil

          expect { subject.resolve!(current_user) }.not_to change { subject.resolved_at }
        end

        it "doesn't change resolved_by" do
          expect(subject.resolved_by).to eq(user)

          expect { subject.resolve!(current_user) }.not_to change { subject.resolved_by }
        end

        it "doesn't change resolved state" do
          expect(subject.resolved?).to be true

          expect { subject.resolve!(current_user) }.not_to change { subject.resolved? }
        end
      end

      context "when some resolvable notes are resolved" do
        before do
          first_note.resolve!(user)
        end

        it "calls resolve! on every resolvable note" do
          expect(first_note).to receive(:resolve!).with(current_user)
          expect(second_note).not_to receive(:resolve!)
          expect(third_note).to receive(:resolve!).with(current_user)

          subject.resolve!(current_user)
        end

        it "doesn't change resolved_at on the resolved note" do
          expect(first_note.resolved_at).not_to be_nil

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved_at }
        end

        it "doesn't change resolved_by on the resolved note" do
          expect(first_note.resolved_by).to eq(user)

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved_by }
        end

        it "doesn't change the resolved state on the resolved note" do
          expect(first_note.resolved?).to be true

          expect { subject.resolve!(current_user) }.not_to change { first_note.resolved? }
        end

        it "sets resolved_at on the unresolved note" do
          subject.resolve!(current_user)

          expect(third_note.resolved_at).not_to be_nil
        end

        it "sets resolved_by on the unresolved note" do
          subject.resolve!(current_user)

          expect(third_note.resolved_by).to eq(current_user)
        end

        it "marks the unresolved note as resolved" do
          subject.resolve!(current_user)

          expect(third_note.resolved?).to be true
        end

        it "sets resolved_at" do
          subject.resolve!(current_user)

          expect(subject.resolved_at).not_to be_nil
        end

        it "sets resolved_by" do
          subject.resolve!(current_user)

          expect(subject.resolved_by).to eq(current_user)
        end

        it "marks as resolved" do
          subject.resolve!(current_user)

          expect(subject.resolved?).to be true
        end
      end

      context "when no resolvable notes are resolved" do
        it "calls resolve! on every resolvable note" do
          expect(first_note).to receive(:resolve!).with(current_user)
          expect(second_note).not_to receive(:resolve!)
          expect(third_note).to receive(:resolve!).with(current_user)

          subject.resolve!(current_user)
        end

        it "sets resolved_at on the unresolved notes" do
          subject.resolve!(current_user)

          expect(first_note.resolved_at).not_to be_nil
          expect(third_note.resolved_at).not_to be_nil
        end

        it "sets resolved_by on the unresolved notes" do
          subject.resolve!(current_user)

          expect(first_note.resolved_by).to eq(current_user)
          expect(third_note.resolved_by).to eq(current_user)
        end

        it "marks the unresolved notes as resolved" do
          subject.resolve!(current_user)

          expect(first_note.resolved?).to be true
          expect(third_note.resolved?).to be true
        end

        it "sets resolved_at" do
          subject.resolve!(current_user)

          expect(subject.resolved_at).not_to be_nil
        end

        it "sets resolved_by" do
          subject.resolve!(current_user)

          expect(subject.resolved_by).to eq(current_user)
        end

        it "marks as resolved" do
          subject.resolve!(current_user)

          expect(subject.resolved?).to be true
        end
      end
    end
  end

  describe "#unresolve!" do
    context "when not resolvable" do
      before do
        allow(subject).to receive(:resolvable?).and_return(false)
      end

      it "returns nil" do
        expect(subject.unresolve!).to be_nil
      end
    end

    context "when resolvable" do
      let(:user) { create(:user) }

      before do
        allow(subject).to receive(:resolvable?).and_return(true)

        allow(first_note).to receive(:resolvable?).and_return(true)
        allow(second_note).to receive(:resolvable?).and_return(false)
        allow(third_note).to receive(:resolvable?).and_return(true)
      end

      context "when all resolvable notes are resolved" do
        before do
          first_note.resolve!(user)
          third_note.resolve!(user)
        end

        it "calls unresolve! on every resolvable note" do
          expect(first_note).to receive(:unresolve!)
          expect(second_note).not_to receive(:unresolve!)
          expect(third_note).to receive(:unresolve!)

          subject.unresolve!
        end

        it "unsets resolved_at on the resolved notes" do
          subject.unresolve!

          expect(first_note.resolved_at).to be_nil
          expect(third_note.resolved_at).to be_nil
        end

        it "unsets resolved_by on the resolved notes" do
          subject.unresolve!

          expect(first_note.resolved_by).to be_nil
          expect(third_note.resolved_by).to be_nil
        end

        it "unmarks the resolved notes as resolved" do
          subject.unresolve!

          expect(first_note.resolved?).to be false
          expect(third_note.resolved?).to be false
        end

        it "unsets resolved_at" do
          subject.unresolve!

          expect(subject.resolved_at).to be_nil
        end

        it "unsets resolved_by" do
          subject.unresolve!

          expect(subject.resolved_by).to be_nil
        end

        it "unmarks as resolved" do
          subject.unresolve!

          expect(subject.resolved?).to be false
        end
      end

      context "when some resolvable notes are resolved" do
        before do
          first_note.resolve!(user)
        end

        it "calls unresolve! on every resolvable note" do
          expect(first_note).to receive(:unresolve!)
          expect(second_note).not_to receive(:unresolve!)
          expect(third_note).to receive(:unresolve!)

          subject.unresolve!
        end

        it "unsets resolved_at on the resolved note" do
          subject.unresolve!

          expect(first_note.resolved_at).to be_nil
        end

        it "unsets resolved_by on the resolved note" do
          subject.unresolve!

          expect(first_note.resolved_by).to be_nil
        end

        it "unmarks the resolved note as resolved" do
          subject.unresolve!

          expect(first_note.resolved?).to be false
        end
      end

      context "when no resolvable notes are resolved" do
        it "calls unresolve! on every resolvable note" do
          expect(first_note).to receive(:unresolve!)
          expect(second_note).not_to receive(:unresolve!)
          expect(third_note).to receive(:unresolve!)

          subject.unresolve!
        end
      end
    end
  end

  describe "#collapsed?" do
    context "when a diff discussion" do
      before do
        allow(subject).to receive(:diff_discussion?).and_return(true)
      end

      context "when resolvable" do
        before do
          allow(subject).to receive(:resolvable?).and_return(true)
        end

        context "when resolved" do
          before do
            allow(subject).to receive(:resolved?).and_return(true)
          end

          it "returns true" do
            expect(subject.collapsed?).to be true
          end
        end

        context "when not resolved" do
          before do
            allow(subject).to receive(:resolved?).and_return(false)
          end

          it "returns false" do
            expect(subject.collapsed?).to be false
          end
        end
      end

      context "when not resolvable" do
        before do
          allow(subject).to receive(:resolvable?).and_return(false)
        end

        context "when active" do
          before do
            allow(subject).to receive(:active?).and_return(true)
          end

          it "returns false" do
            expect(subject.collapsed?).to be false
          end
        end

        context "when outdated" do
          before do
            allow(subject).to receive(:active?).and_return(false)
          end

          it "returns true" do
            expect(subject.collapsed?).to be true
          end
        end
      end
    end

    context "when not a diff discussion" do
      before do
        allow(subject).to receive(:diff_discussion?).and_return(false)
      end

      it "returns false" do
        expect(subject.collapsed?).to be false
      end
    end
  end
end