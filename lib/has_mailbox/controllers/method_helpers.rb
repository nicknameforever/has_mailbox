module HasMailbox
	module Controllers
		module MethodHelpers
			extend ActiveSupport::Concern
			
			def self.define_methods(user_class_name,mapping = {}) 
			  $user_class_name = user_class_name
				if mapping.empty?
					$mapping[:user_object_name] = "current_user"
					$mapping[:user_display_attribute] = "name"
				else
				  $mapping = mapping
				end
			
			  class_eval do
			    	
				def index
					@mailbox = params[:mailbox].blank? ? "inbox" : params[:mailbox]
					@messages = eval($mapping[:user_object_name]).send(@mailbox).paginate(:page => params[:page], :per_page => 10)
					if @mailbox == "inbox"
						@options = ["Read","Unread","Delete"]
					elsif @mailbox == "outbox"
						@options = ["Delete"]
					elsif @mailbox == "trash"
						@options = ["Read","Unread","Delete","Undelete"]	
					end
				end
				
				def show
					unless params[:mailbox].blank?
						@message = eval($mapping[:user_object_name]).send(params[:mailbox]).find(params[:id])
						message_from = @message.from.send($mapping[:user_display_attribute])
						message_to_name = @message.to.name
						message_created_at = @message.created_at.strftime('%A, %B %d, %Y at %I:%M %p')
						unless params[:mailbox] == "outbox"
							read_unread_messages(true,@message)
							@message_description = "On " + message_created_at +' <span class="recipient_name">' + message_from + "</span> wrote :"
							@user_tokens = @message.from.id
						else
							@message_description = "You wrote to <span class='recipient_name'>" + message_to_name + "</span> at " + message_created_at + " :"
						end
					end
				end
				
				def new
				  @user_id = params[:id]
				end
				
				def create
					unless params[:user_tokens].blank? or params[:subject].blank? or params[:body].blank?
						recipients = eval($user_class_name).find(params[:user_tokens].split(",").collect { |id| id.to_i })
						if eval($mapping[:user_object_name]).send_message?(params[:subject],params[:body],*recipients)
							redirect_to mailboxes_url, :notice => 'Successfully send message.'
						else
							flash[:alert] = "Unable to send message."
							render :action => "new"
						end
					else
						flash[:alert] = "Invalid input for sending message."
						render :action => "new"
					end	
				end
				
				def update
					unless params[:messages].nil? 
						messages = eval($mapping[:user_object_name]).send(params[:mailbox]).find(params[:messages])
						if params[:option].downcase == "read"
							read_unread_messages(true,*messages)	
						elsif params[:option].downcase == "unread"
							read_unread_messages(false,*messages)
						elsif params[:option].downcase == "delete"
							delete_messages(true,*messages)
						elsif params[:option].downcase == "undelete"
							delete_messages(false,*messages)
						end
						redirect_to box_mailboxes_url(params[:mailbox])
					else
						redirect_to box_mailboxes_url(params[:mailbox])
					end	
				end  
				
				def token
					query = "%" + params[:q] + "%"
					recipients = eval($user_class_name).select("id,#{$mapping[:user_display_attribute]}").where("#{$mapping[:user_display_attribute]} like ?", query)
					respond_to do |format|
						format.json { render :json => recipients.map { |u| { "id" => u.id, "name" => u.send($mapping[:user_display_attribute])} } }
					end
				end
				
				def read_unread_messages(isRead, *messages)
					messages.each do |msg|
						if isRead
							msg.mark_as_read unless msg.read?
						else
							msg.mark_as_unread if msg.read?
						end	
					end
				end
				
				def delete_messages(isDelete, *messages)
					messages.each do |msg|  
						if isDelete
							msg.delete	
						else
							msg.undelete	
						end	
					end
				end
					
			  end
			
			 end
			
		end	
	end
end
