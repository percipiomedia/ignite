/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.ignite.spi.communication.tcp;

import java.net.InetSocketAddress;
import java.util.Collection;
import java.util.regex.PatternSyntaxException;

import org.apache.ignite.Ignite;
import org.apache.ignite.configuration.IgniteConfiguration;
import org.apache.ignite.testframework.junits.spi.GridSpiAbstractConfigTest;
import org.apache.ignite.testframework.junits.spi.GridSpiTest;
import org.junit.Assert;

import com.google.common.collect.Sets;

import static org.apache.ignite.testframework.GridTestUtils.getFreeCommPort;

/**
 * TCP communication SPI config test.
 */
@GridSpiTest(spi = TcpCommunicationSpi.class, group = "Communication SPI")
public class GridTcpCommunicationSpiConfigSelfTest extends GridSpiAbstractConfigTest<TcpCommunicationSpi> {

	/** {@inheritDoc} */
    @Override
	protected void afterTest() throws Exception {
        stopAllGrids();
	}

	/**
     * @throws Exception If failed.
     */
    public void testNegativeConfig() throws Exception {
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "localPort", 1023);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "localPort", 65636);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "localPortRange", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "idleConnectionTimeout", 0);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "socketReceiveBuffer", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "socketSendBuffer", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "messageQueueLimit", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "reconnectCount", 0);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "selectorsCount", 0);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "connectTimeout", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "maxConnectTimeout", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "socketWriteTimeout", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "ackSendThreshold", 0);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "ackSendThreshold", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "unacknowledgedMessagesBufferSize", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "connectionsPerNode", 0);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "connectionsPerNode", -1);
        checkNegativeSpiProperty(new TcpCommunicationSpi(), "connectionsPerNode", Integer.MAX_VALUE);
    }

    /**
     * @throws Exception If failed.
     */
    public void testLocalPortRange() throws Exception {
        IgniteConfiguration cfg = getConfiguration();

        TcpCommunicationSpi commSpi = new TcpCommunicationSpi();

        commSpi.setLocalPortRange(0);
        commSpi.setLocalPort(getFreeCommPort());

        cfg.setCommunicationSpi(commSpi);

        startGrid(cfg);
    }

    public void testNodeAddressExclusionFilters() throws Exception {
       IgniteConfiguration cfg = getConfiguration();

       TcpCommunicationSpi spi = new TcpCommunicationSpi();
       cfg.setCommunicationSpi(spi);

       Ignite ignite = startGrid(cfg.getIgniteInstanceName(), cfg);


       // Validate the node addresses for the only node contains the local node address.
       Collection<InetSocketAddress> unfilteredAddresses = spi.nodeAddresses(ignite.cluster().node(), false);
       boolean containsLocalAddress = false;
       for(InetSocketAddress unfilteredAddress : unfilteredAddresses) {
          if(unfilteredAddress.getAddress().getHostAddress().equals("127.0.0.1")) {
             containsLocalAddress = true;
             break;
          }
       }
       Assert.assertTrue(containsLocalAddress);

       // Tell the SPI to filter the local address and make sure it isn't returned by nodeAddress().
       spi.setNodeAddressExclusionFilters(Sets.newHashSet("127[.]0[.]0[.]1"));
       containsLocalAddress = false;
       Collection<InetSocketAddress> filteredAddresses = spi.nodeAddresses(ignite.cluster().node(), false);
       for(InetSocketAddress filteredAddress : filteredAddresses) {
          if(filteredAddress.getAddress().getHostAddress().equals("127.0.0.1")) {
             containsLocalAddress = true;
             break;
          }
       }
       Assert.assertFalse(containsLocalAddress);

       // Try to configure an invalid filter.
       boolean filterInvalid = false;
       try {
          spi.setNodeAddressExclusionFilters(Sets.newHashSet("["));
       } catch (PatternSyntaxException e) {
          filterInvalid = true;
       }
       Assert.assertTrue(filterInvalid);
   }
}
