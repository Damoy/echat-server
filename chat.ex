# --------------------------------------
# Concurrent Programming
# BENZA Amandine - FORNALI Damien
# Master II - IFI - Software Architecture
# Nice-Sophia-Antipolis University / Polytech
# 2018-2019
# --------------------------------------
# Subject: http://users.polytech.unice.fr/~eg/TMPC/Tds/Td3/sujet.html
# Course: http://users.polytech.unice.fr/~eg/TMPC/Cours/07_elixir_conc.html#(28)
#--------------------------------------
# Concurrent chat server in Elixir
#--------------------------------------

#------------------ Structures --------------------
defmodule User do
    defstruct socket: nil, pseudo: nil, pid:  -1, idleTime: 0
end

defmodule Timeout do
    def maxIdle do 9 end
end

#------------------ Core --------------------

defmodule ChatServer do
    # Entry point
    def main() do
        {options, _, _} = OptionParser.parse(System.argv, switches: [port: :integer]);
        run(self(), (if options[:port], do: options[:port], else: 12345));
        innerMain();
    end

    # Used to receive broadcast requests
    def innerMain() do
        spawn(ChatServer, :idleChecker, [self()]);
        innerMain([]);
    end

    # Checks for users idle timeout
    def idleChecker(mainPid) do
        Process.sleep(1000);
        send(mainPid, :updateIdle);
        idleChecker(mainPid);
    end

    def innerMain(users) do
        receive do
            :end -> Log.message("Server closing..."); # end of server processing
            {:adduser, user} -> # to add a new user to memory
                users = users ++ [user];
                Log.message("User #{user.pseudo} stored in memory.");
                innerMain(users);
            {:broadcastExcept, pseudoExcept,  msg} -> # broadcast a message to everyone except one
                Enum.map(Enum.filter(users, fn us -> us.pseudo != pseudoExcept end),
                            fn us -> Message.write_line(us.socket, msg) end);
                innerMain(users);

            {:broadcast, msg} -> # broadcast a message to everyone
                Enum.each users, fn user ->
                    Message.write_line(user.socket, msg);
                end
                innerMain(users);

            {:removeuser, userPseudo} -> # remove a user from the memory
                userToDelete = Enum.find(users, fn us -> (us.pseudo == userPseudo) end);
                users = List.delete(users, userToDelete);
                Message.write_line(userToDelete.socket, "#{userPseudo} seems to be afk. Force disconnection.\n");
                Log.message("#{userPseudo} force disconnection");
                Process.exit(userToDelete.socket, :closed);
                innerMain(users);
            :updateIdle -> # updates idle time of all users
                Log.message("Update idle time !");

                # --------- Trials for idle time force disconnection---------

                # newUsersList = [];
                # for i <- 0..3 do
                #     user = Enum.at(i);
                #     newUsersList = newUsersList ++ [%User{socket: user.socket, pseudo: user.pseudo, pid: user.pid, idleTime: user.idleTime + 1}];
                # end
                # Enum.each users, fn user ->
                #     newUsersList = newUsersList ++ [%User{socket: user.socket, pseudo: user.pseudo, pid: user.pid, idleTime: user.idleTime + 1}];
                # end
                # Enum.map(users, fn us -> newUsersList = newUsersList ++ 
                #     [%User{socket: user.socket, pseudo: user.pseudo, pid: user.pid, idleTime: user.idleTime + 1}] end);

                # Enum.map(Enum.filter(users, fn us -> us.idleTime + 1 >= 10 end),
                #         fn us -> Log.message("GO DOWN");
                #             Message.write_line(us.socket, "#{us.pseudo} seems to be afk. Force disconnection.\n");
                #             Log.message("#{us.pseudo} force disconnection");
                #             Process.exit(us.socket, :closed); end);

                # newUsersList = Enum.filter(users, fn us -> us.idleTime + 1 < 10 end); 

                # Enum.each users, fn user -> 

                #     # newUser = %User{socket: user.socket, pseudo: user.pseudo, pid: user.pid, idleTime: user.idleTime + 1};
                #     # Log.message("#{newUser.pseudo} idle time updated: #{newUser.idleTime}.");
                #     # users = List.delete(users, user);
                    
                #     cond do 
                #         user.idleTime + 1 < 10 ->
                #             newUsersList = Enum.concat(newUsersList, [%User{socket: user.socket, pseudo: user.pseudo, pid: user.pid, idleTime: user.idleTime + 1}]);
                #             Log.message("Updated: #{user.idleTime + 1}");
                #         user.idleTime + 1 >= 10 ->
                #             Log.message("GO DOWN");
                #             Message.write_line(user.socket, "#{user.pseudo} seems to be afk. Force disconnection.\n");
                #             Log.message("#{user.pseudo} force disconnection");
                #             Process.exit(user.socket, :closed);
                #     end
                # end

                # update new users list and recurse
                innerMain(users);
            end
    end

    # Create the server listener and launch the 'acceptor' 
    def run(mainPid, port) do
        case :gen_tcp.listen(port, [:binary, packet: :line, active: false,
                                           reuseaddr: true]) do
            {:ok, listenerSocket} ->
                Log.message("Starting server on port #{port}...");
                spawn(ChatServer, :accept, [mainPid, listenerSocket]);
            {:error, reason} -> 
                Log.message("Failed to launch server. #{reason}");
        end
    end

    # Accepts new connections
    def accept(mainPid, listenerSocket) do
        {:ok, clientSocket} = :gen_tcp.accept(listenerSocket);
       innerAccept(mainPid, listenerSocket, clientSocket);
    end

    # Helper to be able to recurse
    # Asks for user pseudo and recurse if inquired is invalid
    def innerAccept(mainPid, listenerSocket, clientSocket) do
        Message.write_line(clientSocket, ">> Enter pseudo: ");
        ipseudo = Message.read_line(mainPid, self(), "", clientSocket);
        ipseudo = String.replace(ipseudo, "\n", "");

        case ipseudo == nil || ipseudo == "" || ipseudo == "\n"
            || ipseudo == "\t" do
            true ->
                # Redo
                innerAccept(mainPid, listenerSocket, clientSocket);
            false ->
                # Create new user
                user = %User{socket: clientSocket, pseudo: ipseudo, pid: self(), idleTime: 0};
                # Inform to main processor
                send(mainPid, {:adduser, user});

                # Inform of new connection
                Log.message("#{ipseudo} connected.");
                send(mainPid, {:broadcast, ">> Welcome #{ipseudo} !\n"});

                # Serve the user
                spawn(ChatServer, :serve, [mainPid, ipseudo, clientSocket]);
                # Recurse
                accept(mainPid, listenerSocket);
        end
    end

    # Serves a user
    def serve(mainPid, pseudo, clientSocket) do
        line = Message.read_line(mainPid, self(), pseudo, clientSocket);
        # send broadcast event to main processor
        send(mainPid, {:broadcastExcept, pseudo, "#{pseudo}: #{line}"});
        serve(mainPid, pseudo, clientSocket);
    end

end

#------------------ Messages --------------------
defmodule Message do
  def read_line(mainPid, pid, userPseudo, clientSocket) do
    case :gen_tcp.recv(clientSocket, 0) do
        {:ok, line} ->
            line
        {:error, :closed} -> # end processor on close
            send(mainPid, {:broadcast, ">> Bye #{userPseudo} !\n"});
            Log.message("#{userPseudo} disconnected.");
            Process.exit(pid, :closed);
        {:error, :enotconn} -> # end processor on error
            send(mainPid, {:broadcast, ">> Bye #{userPseudo} !\n"});
            Log.message("#{userPseudo} disconnected.");
            Process.exit(pid, :enotconn);
    end
  end

  def write_line(clientSocket, line) do
    :gen_tcp.send(clientSocket, line)
  end
end

defmodule Log do
  def message(str) do
    fmt = fn nb -> nb |> Integer.to_string |> String.pad_leading(2, "0") end

    {{d,m,y}, {h,min,s}}  = :calendar.local_time()
    IO.puts("#{fmt.(y)}/#{fmt.(m)}/#{fmt.(d)} " <>
            "#{fmt.(h)}:#{fmt.(min)}:#{fmt.(s)} #{str}")
  end
end

#------------------ Launch  --------------------
ChatServer.main();