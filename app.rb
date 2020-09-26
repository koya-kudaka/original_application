require "sinatra"
require "sinatra/reloader"
require "sinatra/cookies"
require "pg"
require "pry"
require "digest"

client = PG::connect(
    :host => "localhost",
    :user => ENV.fetch("DB_USER", "kudaka"),
    :password => '',
    :dbname => "healthapp"
)

enable :sessions




# サインアップリクエスト
get "/signup" do
    return erb :signup
end

post "/signup" do
    if params[:name].empty? || params[:user_id].empty? || params[:email].empty? || params[:password].empty?
        return redirect "/signup"
    else
        name = params[:name]
        user_id = params[:user_id]
        email = params[:email]
        password = params[:password]

        client.exec_params(
            "INSERT INTO users (name, user_id, email, password) VALUES ($1, $2, $3, $4)",
            [name, user_id, email, password]
        )

        user = client.exec_params(
            "SELECT * FROM users WHERE email = $1 AND password = $2 LIMIT 1",
            [email, password]
        ).to_a.first

        session[:user] = user
        @user_id = session[:user]['user_id']
        return redirect "/data/#{@user_id}"
    end
end

# ログイン　リクエスト
get "/login" do
    return erb :login
end

post "/login" do
    email = params[:email]
    password = params[:password]

    user = client.exec_params(
        "SELECT * FROM users WHERE email = $1 AND password = $2 LIMIT 1",
        [email, password]
    ).to_a.first

    if user.nil?
        return redirect "/login"
    else
        session[:user] = user
        user_id = session[:user]['user_id']

        return redirect "/data/#{user_id}"
    end
end

# ログアウト　リクエスト
delete "/logout" do
    session[:user] = nil
    return redirect "/login"
end

# "/dataを表示するルーティング"
get "/data/:user_id" do
    user_id = params[:user_id]
    @user_id = session[:user]['user_id']
    @user_name = session[:user]['name']
    @user_data = client.exec_params(
        "SELECT * FROM users_data WHERE user_id = $1 LIMIT 1",
        [user_id]
    ).to_a.first

    p @user_data
    return erb :data
end

post "/data/:user_id" do
    user_id = params[:user_id]
    if params[:first_weight].empty? || params[:goal_weight].empty? || params[:first_date].empty? || params[:period].empty? || params[:con_kcal].empty?
        return redirect "/data/#{user_id}"
    else
        first_weight = params[:first_weight].to_i
        goal_weight = params[:goal_weight].to_i
        first_date = params[:first_date]
        period = params[:period].to_i
        con_kcal = params[:con_kcal].to_i
    
        plus_kcal = ((goal_weight - first_weight) * 7200) / period
        goal_kcal = con_kcal + plus_kcal
        
        # ここで各変数をusers_dataテーブルに保存
        client.exec_params(
            "INSERT INTO users_data (first_weight, goal_weight, period, con_kcal, plus_kcal, goal_kcal, user_id, first_date) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            [first_weight, goal_weight, period, con_kcal, plus_kcal, goal_kcal, user_id, first_date]
        )

        return redirect "/data/#{user_id}"
    end
end


# ページ情報編集　リクエスト
get "/data/:user_id/edit" do
    @user_id = session[:user]['user_id']
    return erb :data_edit
end

put "/data/:user_id/update" do
    user_id = params[:user_id]

    if params[:refirst_weight].empty? || params[:regoal_weight].empty? || params[:refirst_date].empty? || params[:reperiod].empty? || params[:recon_kcal].empty?
        return redirect "/data/#{user_id}/edit"
    else
        refirst_weight = params[:refirst_weight].to_i
        regoal_weight = params[:regoal_weight].to_i
        refirst_date = params[:refirst_date]
        reperiod = params[:reperiod].to_i
        recon_kcal = params[:recon_kcal].to_i

        p refirst_weight

        replus_kcal = ((regoal_weight - refirst_weight) * 7200) / reperiod
        regoal_kcal = recon_kcal + replus_kcal

        client.exec_params(
            "UPDATE users_data SET 
            first_weight = '#{refirst_weight}', 
            goal_weight = '#{regoal_weight}',
            first_date = '#{refirst_date}', 
            period = '#{reperiod}',
            con_kcal = '#{recon_kcal}',
            plus_kcal = '#{replus_kcal}',
            goal_kcal = '#{regoal_kcal}'
            WHERE user_id = '#{user_id}'"
        )
        return redirect "/data/#{user_id}"
    end
end


# カロリー情報　リクエスト
get "/calorie/get/:user_id" do
    user_id = params[:user_id]
    @user_id = session[:user]['user_id']
    @user_name = session[:user]['name']
    @goal_kcal = client.exec_params(
        "SELECT goal_kcal FROM users_data WHERE user_id = '#{user_id}'"
    ).to_a.first

    @user_kcal = client.exec_params(
        "SELECT total_kcal FROM calorie WHERE date = '#{Date.today}' AND user_id = '#{user_id}'"
    ).to_a.first

    if @user_kcal.nil?
        client.exec_params(
            "INSERT INTO calorie (total_kcal, user_id) VALUES ($1, $2)",
            [0, user_id]
        )
        @need_kcal = 0
    else
        @need_kcal = @goal_kcal['goal_kcal'].to_i - @user_kcal['total_kcal'].to_i
    end
    
    return erb :get_calorie
end


post "/calorie/get/:user_id" do
    user_id = params[:user_id]
    today = Date.today

    if params[:get_calorie].empty?
        get_calorie = 0
    else
        get_calorie = params[:get_calorie].to_i
    end

    
    client.exec_params(
        "UPDATE calorie SET total_kcal = total_kcal + '#{get_calorie}' WHERE date = '#{today}' AND user_id = '#{user_id}'"
    )

    return redirect "/calorie/get/#{user_id}"
end


get "/weight/:user_id" do
    user_id = params[:user_id]
    @user_id = session[:user]['user_id']

    @users_weight = client.exec_params(
        "SELECT * FROM users_weight WHERE user_id = '#{user_id}' LIMIT 30"
    ).to_a.sort_by{|a| a['date']}
    
    @day = []
    @users_weight.each do |user_weight|
        @day.push(user_weight['date'])
    end

    @weight = []
    @users_weight.each do |user_weight|
        @weight.push(user_weight['weight'])
    end
    p @day
    p @weight
    
    return erb :weight
end

post "/weight/:user_id" do
    user_id = params[:user_id]

    if params[:weight].empty? || params[:date].empty?
        return redirect "/weight/#{user_id}"
    else
        weight = params[:weight]
        date = params[:date]

        exist_weight = client.exec_params(
            "SELECT * FROM users_weight WHERE date = '#{date}'  AND user_id = '#{user_id}'"
        ).to_a.first

        if exist_weight.nil?
            client.exec_params(
                "INSERT INTO users_weight (weight, date, user_id) VALUES ($1, $2, $3)",
                [weight, date, user_id]
            )
        else
            client.exec_params(
                "UPDATE users_weight SET weight = '#{weight}' WHERE date = '#{date}' AND user_id = '#{user_id}'"
            )
        end
        return redirect "/weight/#{user_id}"
    end
end


# 日記機能のリクエスト

get "/posts" do
    
    if session[:user].nil?
        return redirect '/login'
    end

    @name = session
    # dbから値を取得してインスタンス変数に代入
    @posts = client.exec_params(
        "SELECT * FROM posts"
    ).to_a.sort_by{|a| a['created_at']}.reverse

    return erb :posts
end

post "/posts" do
    
    name = params[:name]
    user_id = params[:user_id]
    content = params[:content]
    img_name = ''

    if !params[:img].nil?
        tempfile = params[:img][:tempfile]
        save_to = "./public/images/#{params[:img][:filename]}"
        FileUtils.mv(tempfile, save_to)
        img_name = params[:img][:filename]
    end

    # dbに値を保存する insert文実行

    client.exec_params(
        "INSERT INTO posts (name, user_id, content, image_path) VALUES ($1, $2, $3, $4)",
        [name, user_id, content, img_name]
    )

    return redirect "/posts"
end


post "/like" do
    post_id = params[:post_id]
    user_id = params[:user_id]

    exist_like = client.exec_params(
        "SELECT * FROM likes WHERE post_id = '#{post_id}' AND user_id = '#{user_id}'"
    ).to_a.first

    # likesテーブルにいいね！の実行があったことを保存する
    if exist_like.nil?
        client.exec_params(
            "INSERT INTO likes (post_id, user_id) VALUES ($1, $2)",
            [post_id, user_id]
        )
    else
        client.exec_params(
            "DELETE FROM likes WHERE post_id = '#{post_id}' AND user_id = '#{user_id}'"
        )
    end

    # postsテーブルのlikeの数を更新する
    count_like = client.exec_params(
        "SELECT count(*) FROM likes WHERE post_id = '#{post_id}'"
    ).to_a.first['count']


    client.exec_params(
        "UPDATE posts SET count_get_like = '#{count_like}' WHERE id = '#{post_id}'"
    )

    return redirect "/posts"
end