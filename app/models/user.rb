class User < ApplicationRecord
    acts_as_taggable_on :hobbies
end
