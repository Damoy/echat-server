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
# Parallel chat server in Elixir
#--------------------------------------

#------------------ Core --------------------

defmodule ChatServer do
    def read_line(socket) do
        {:ok, line} = :gen_tcp.recv(socket, 0);
        line;
    end

    defp write_line(line, socket) do
        :gen_tcp.send(socket, line);
    end

    # ERROR TODO
    def serve(socket) do
        receive do
        {"go", proc} ->
            "You said: #{read_line(socket)}" |> write_line(socket);
            send(self(), {"go", self()});
            IO.puts(proc, "Test");

        _ -> IO.puts(:stderr, "Weird message")
        end
    end

    # ERROR TODO
    # Wait a client
    # Serve new client
    # Loop back
    def accept(socket) do
        {:ok, client} = :gen_tcp.accept(socket);
        proc = spawn(ChatServer, :serve, client);
        send(proc, {"go", self()});
        accept(socket);
    end

    def run(port) do
        Log.message("Running server on port #{port}");
        {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false,
                                           reuseaddr: true]);
        accept(socket);
    end

    def main() do
        {options, _, _} = OptionParser.parse(System.argv, switches: [port: :integer]);
        run(if options[:port], do: options[:port], else: 12345);
    end
end


#------------------ Logging --------------------

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