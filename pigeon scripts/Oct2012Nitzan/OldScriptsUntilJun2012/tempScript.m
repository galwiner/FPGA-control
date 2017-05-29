    for j=600:50:850
        disp(j)
        PhotonIonSemiRamsey(j);
        pause(10);
        if dic.stop
            return;
        end
    end
