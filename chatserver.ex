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
  use GenServer

  def main() do
    {options, _, _} = OptionParser.parse(System.argv, switches: [port: :integer]);
    run(if options[:port], do: options[:port], else: 12345);
  end

  def run(port) do
    Log.message("Starting server on port  #{port}...");
    start_link(port);
  end

  def start_link(port) do
    ip = Application.get_env :tcp_server, :ip, {127,0,0,1}
    port = Application.get_env :tcp_server, :port, port
    GenServer.start_link(__MODULE__,[ip,port],[])
  end

  def init [ip,port] do
    {:ok,listen_socket}= :gen_tcp.listen(port,[:binary,{:packet, 0},{:active,true},{:ip,ip}])
    {:ok,socket } = :gen_tcp.accept listen_socket
    {:ok, %{ip: ip,port: port,socket: socket}}
  end

  def handle_info({:tcp,socket,packet},state) do
    IO.inspect packet, label: "incoming packet"
    :gen_tcp.send socket,"Hi Blackode \n"
    {:noreply,state}
  end

  def handle_info({:tcp_closed,_},state) do
    IO.inspect "Socket has been closed"
    {:noreply,state}
  end

  def handle_info({:tcp_error,socket,reason},state) do
    IO.inspect socket,label: "connection closed dut to #{reason}"
    {:noreply,state}
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
iex -S mix